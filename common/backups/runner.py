#!/usr/bin/env python3
"""Unattended machine backup operations; secrets remain in runtime files."""

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import selectors
import shlex
import shutil
import sqlite3
import stat
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request


class Failure(Exception):
    def __init__(self, message, transient=False):
        super().__init__(message)
        self.transient = transient


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file, code, message, headers, url):
        # Do not forward the application token to a redirect destination.
        return None


def utcnow():
    return datetime.now(timezone.utc)


def parsed_time(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


class Runner:
    def __init__(self, config):
        self.config = config
        self.state = Path(config["stateDirectory"])
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.state.chmod(0o700)
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith("RESTIC_") and key != "SSH_AUTH_SOCK"}
        self.env["TZ"] = "UTC"
        self.base = ["restic", "--repo", config["repository"], "--password-file",
                     config["passwordFile"], "--retry-lock", "15m"]
        self.ssh = None
        if config.get("ssh"):
            ssh = config["ssh"]
            command = [
                "ssh", "-F", "/dev/null", "-i", ssh["identityFile"],
                "-o", "IdentitiesOnly=yes",
                "-o", "IdentityAgent=none", "-o", "BatchMode=yes",
                "-o", "StrictHostKeyChecking=yes",
                "-o", "UserKnownHostsFile=" + ssh["knownHostsFile"],
                "-o", "GlobalKnownHostsFile=/dev/null",
                "-o", "ControlMaster=no", "-o", "ControlPath=none",
                "-o", "ControlPersist=no", "-o", "PasswordAuthentication=no",
                "-o", "KbdInteractiveAuthentication=no", "-o", "ConnectTimeout=20",
                "-o", "ConnectionAttempts=1",
            ]
            target = ssh["user"] + "@" + ssh["host"]
            # Hetzner's SFTP service and remote command service use separate ports.
            self.ssh = command + ["-p", str(ssh.get("commandPort", ssh["port"])), target]
            if config["repository"].startswith("sftp:"):
                sftp = command + ["-p", str(ssh["port"]), target, "-s", "sftp"]
                self.base.extend(["-o", "sftp.command=" + shlex.join(sftp)])
        elif config["repository"].startswith("sftp:"):
            raise Failure("SFTP requires an explicit backup SSH identity and pinned host trust")

    def progress(self, message):
        self.current_phase = message
        self.log_progress(message)

    def log_progress(self, message):
        print("[%s] machine-backup: %s" % (utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"), message),
              file=sys.stderr, flush=True)

    @contextmanager
    def phase(self, message):
        self.progress(message)
        started = time.monotonic()
        stopped = threading.Event()
        def heartbeat():
            while not stopped.wait(15):
                self.log_progress("%s (still running, %.0fs elapsed)" %
                                  (self.current_phase, time.monotonic() - started))
        # Keep heartbeats separate from work, including blocking capture commands.
        thread = threading.Thread(target=heartbeat, daemon=True)
        thread.start()
        try:
            yield
        finally:
            stopped.set()
            thread.join()

    def stream_backup(self, arguments):
        environment = dict(self.env, RESTIC_PROGRESS_FPS="0.2")
        summary, errors = "", ""
        with subprocess.Popen(self.base + list(arguments), env=environment,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
            with selectors.DefaultSelector() as selector:
                buffers = {process.stdout: b"", process.stderr: b""}
                for pipe in buffers:
                    selector.register(pipe, selectors.EVENT_READ)
                def consume(pipe, line):
                    nonlocal summary, errors
                    text = line.decode(errors="replace")
                    if pipe is process.stderr:
                        errors = (errors + text + "\n")[-16384:]
                        if text.strip():
                            self.progress("restic: " + text)
                        return
                    if not text.strip():
                        return
                    event = json.loads(text)
                    if event.get("message_type") == "summary":
                        summary = text + "\n"
                    elif event.get("message_type") == "status":
                        self.progress(
                            "Uploading: %.1f%%; %d/%d files; %.1f/%.1f MiB; %d errors" % (
                                event.get("percent_done", 0) * 100,
                                event.get("files_done", 0), event.get("total_files", 0),
                                event.get("bytes_done", 0) / 1048576,
                                event.get("total_bytes", 0) / 1048576,
                                event.get("error_count", 0),
                            ))
                try:
                    while selector.get_map():
                        for key, _ in selector.select():
                            pipe = key.fileobj
                            chunk = os.read(pipe.fileno(), 65536)
                            if not chunk:
                                selector.unregister(pipe)
                                if buffers[pipe]:
                                    consume(pipe, buffers[pipe])
                                continue
                            buffers[pipe] += chunk
                            while b"\n" in buffers[pipe]:
                                line, buffers[pipe] = buffers[pipe].split(b"\n", 1)
                                consume(pipe, line)
                    process.wait()
                except BaseException:
                    process.kill()
                    process.wait()
                    raise
        # Retain only the summary and bounded diagnostics, not hours of progress.
        return subprocess.CompletedProcess(process.args, process.returncode, summary, errors)

    def update(self, change):
        with (self.state / "state.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            path = self.state / "state.json"
            data = json.loads(path.read_text()) if path.exists() else {}
            result = change(data)
            temporary = self.state / "state.json.tmp"
            temporary.write_text(json.dumps(data, indent=2) + "\n")
            temporary.chmod(0o600)
            temporary.replace(path)
            return result

    def transition(self, key, level, message):
        def change(data):
            components = data.setdefault("health", {})
            previous = components.get(key, {}).get("level", "ok")
            if previous == level:
                return
            components[key] = {"level": level, "message": message,
                               "changedAt": utcnow().isoformat()}
            data.setdefault("notifications", []).append({
                "title": "Backups: " + self.config["host"],
                "message": ("Recovered: " if level == "ok" else "") + message,
                "priority": 8 if level == "critical" else 5 if level != "ok" else 2,
            })
        self.update(change)

    def notify(self):
        gotify = self.config.get("gotify")
        if not gotify or not gotify.get("tokenFile"):
            return
        def deliver(data):
            pending = data.setdefault("notifications", [])
            try:
                token = Path(gotify["tokenFile"]).read_text().strip()
                if not token:
                    raise OSError("Empty Gotify token")
                data["notificationDelivery"] = {"level": "ok"}
                for _ in range(min(len(pending), 3)):
                    request = urllib.request.Request(
                        gotify["url"].rstrip("/") + "/message",
                        data=json.dumps(pending[0]).encode(),
                        headers={"X-Gotify-Key": token, "Content-Type": "application/json"},
                    )
                    with urllib.request.build_opener(NoRedirect()).open(request, timeout=15) as response:
                        response.read()
                    pending.pop(0)
            except (OSError, urllib.error.URLError) as error:
                # Keep every undelivered transition, including recovery, for retry.
                data["notificationDelivery"] = {
                    "level": "unavailable", "checkedAt": utcnow().isoformat(),
                    "pending": len(pending), "reason": "missing-credentials" if isinstance(error, OSError)
                    and not isinstance(error, urllib.error.URLError) else "delivery-failed",
                }
                print("Gotify unavailable; notification queued", file=sys.stderr)
        self.update(deliver)

    def restic(self, *arguments, check=True, stream=False):
        self.credentials()
        result = (self.stream_backup(arguments) if stream else
                  subprocess.run(self.base + list(arguments), env=self.env,
                                 capture_output=True, text=True))
        if check and result.returncode:
            text = result.stderr.lower()
            if result.returncode == 12 or any(marker in text for marker in [
                "permission denied", "authentication failed", "unable to authenticate",
                "no supported methods remain", "unable to read password file",
                "host key verification failed", "remote host identification has changed",
            ]):
                raise Failure("Repository credentials were rejected")
            if "no space left" in text or "quota exceeded" in text:
                raise Failure("Backup target is full")
            if result.returncode == 3:
                raise Failure("Incomplete backup: some source data was unreadable")
            if any(marker in text for marker in ["repository contains errors", "repository is damaged",
                                                 "does not match hash", "does not match id"]):
                raise Failure("Repository integrity verification failed")
            raise Failure("Repository operation failed (exit %d)" % result.returncode,
                          transient=True)
        return result

    def credentials(self):
        password = self.config["passwordFile"]
        if not Path(password).is_file() or not os.access(password, os.R_OK):
            raise Failure("Repository password file is missing or unreadable")
        if self.config["repository"].startswith("sftp:"):
            ssh = self.config["ssh"]
            if not Path(ssh["identityFile"]).is_file() or not os.access(ssh["identityFile"], os.R_OK):
                raise Failure("Dedicated backup SSH private key is missing or unreadable")
            if not Path(ssh["knownHostsFile"]).is_file():
                raise Failure("Pinned Storage Box host trust is missing")

    def initialize(self):
        result = self.restic("cat", "config", check=False)
        if result.returncode == 10:
            self.progress("Initializing backup repository")
            # A concurrent host can win initialization. Verify the final result.
            self.restic("init", "--repository-version", "2", check=False)
            self.restic("cat", "config")
        elif result.returncode:
            self.restic("cat", "config")

    def backup(self, scope):
        specification = self.config["scopes"][scope]
        with self.phase("%s: checking backup repository" % scope):
            self.initialize()
        captured_at = utcnow()
        paths = list(specification.get("paths", []))
        if specification.get("captures"):
            from capture import CaptureError, prepare
            try:
                with self.phase("%s: preparing local captures" % scope):
                    paths.extend(map(str, prepare(
                        specification, self.state / "staging" / scope,
                        timeout_seconds=self.config.get("timeoutSeconds", 60),
                        progress=self.progress,
                    )))
            except CaptureError as error:
                raise Failure("Service capture failed: " + str(error)) from error
        if not paths:
            raise Failure("Backup scope has no source paths")
        if any(not Path(path).is_absolute() or not (Path(path).exists() or Path(path).is_symlink())
               for path in paths):
            raise Failure("A required backup source is missing or is not an absolute path")
        arguments = ["backup", "--json", "--host", self.config["host"],
                     "--tag", "machine-backup", "--tag", scope,
                     "--group-by", "host,paths", "--time",
                     captured_at.strftime("%Y-%m-%d %H:%M:%S"),
                     "--exclude", ".direnv"]
        for exclusion in specification.get("excludes", []):
            arguments.extend(["--exclude", exclusion])
            if exclusion.startswith("/"):
                arguments.extend(["--exclude", str(self.state / "staging" / scope / "tree") + exclusion])
        for exclusion in specification.get("directExcludes", []):
            arguments.extend(["--exclude", exclusion])
        with self.phase("%s: scanning and uploading backup" % scope):
            result = self.restic(*arguments, "--", *paths, stream=True)
        summaries = [json.loads(line) for line in result.stdout.splitlines()
                     if line.strip()]
        snapshot = next((item.get("snapshot_id") for item in summaries
                         if item.get("message_type") == "summary"), None)
        if not snapshot:
            raise Failure("Successful upload did not return a restore point")
        with self.phase("%s: marking snapshot complete" % scope):
            self.restic("tag", "--add", "complete", snapshot)
        def completed(data):
            data.setdefault("firstCompleteAt", utcnow().isoformat())
            data.setdefault("lastComplete", {})[scope] = {
                "capturedAt": captured_at.isoformat(), "uploadedAt": utcnow().isoformat(),
            }
            data.setdefault("lastFailure", {}).pop("backup:" + scope, None)
        with self.phase("%s: recording backup status" % scope):
            self.update(completed)
            self.transition("backup:" + scope, "ok", scope + " backup succeeded")
        self.progress("%s: backup complete" % scope)
        print(json.dumps({"host": self.config["host"], "scope": scope,
                          "capturedAt": captured_at.isoformat(), "complete": True}))

    def snapshots(self, complete=False):
        tags = "machine-backup,complete" if complete else "machine-backup"
        return json.loads(self.restic("snapshots", "--json", "--tag", tags).stdout) or []

    def maintain(self, dry_run=False):
        if self.config["host"] != "loem":
            raise Failure("Shared repository maintenance is owned by loem")
        # Verify repository structure and one deterministic quarter before deleting data.
        quarter = self.update(lambda data: data.get("nextCheckQuarter", 1))
        if not dry_run:
            self.restic("check", "--read-data-subset", str(quarter) + "/4")
        candidates = [point["id"] for point in self.snapshots()
                      if "complete" not in point.get("tags", [])
                      and (utcnow() - parsed_time(point["time"])).total_seconds() > 7 * 86400]
        if candidates:
            options = ["--dry-run"] if dry_run else []
            self.restic("forget", *options, *candidates)
        options = ["--dry-run"] if dry_run else []
        result = self.restic(
            "forget", "--tag", "machine-backup,complete", "--group-by", "host,tags",
            "--keep-within", "7d", "--keep-within-daily", "30d",
            "--keep-within-weekly", "84d", "--keep-within-monthly", "1y", *options,
        )
        print(result.stdout.strip())
        if not dry_run:
            self.restic("prune")
            self.update(lambda data: data.update({
                "nextCheckQuarter": quarter % 4 + 1,
                "lastIntegrityCheck": {"at": utcnow().isoformat(), "quarter": quarter},
                "lastMaintenance": utcnow().isoformat(),
            }))
            self.transition("maintain:repository", "ok", "Repository maintenance succeeded")

    def rehearsal_reminder(self):
        quarter = str(utcnow().year) + "-Q" + str((utcnow().month - 1) // 3 + 1)
        def change(data):
            if data.get("rehearsalReminder") == quarter:
                return
            data["rehearsalReminder"] = quarter
            data.setdefault("notifications", []).append({
                "title": "Backup recovery rehearsal",
                "message": "Run this quarter's isolated home and service restore rehearsal; "
                           "record recovery time and coverage gaps in the backup runbook.",
                "priority": 3,
            })
        self.update(change)

    def capacity_unavailable(self):
        previous = self.update(lambda data: data.get("capacity", {}).get("checkedAt"))
        if not previous or (utcnow() - parsed_time(previous)).total_seconds() > 12 * 3600:
            self.transition("capacity", "warning", "Storage Box capacity cannot be measured")

    def check_capacity(self):
        try:
            result = subprocess.run(self.ssh + ["df", "-kP", "."], env=self.env,
                                    capture_output=True, text=True, timeout=45)
        except subprocess.TimeoutExpired as error:
            raise Failure("Storage Box capacity request timed out", transient=True) from error
        if result.returncode:
            if "permission denied" in result.stderr.lower():
                self.transition("capacity", "critical", "Storage Box capacity credentials were rejected")
            else:
                self.capacity_unavailable()
            return
        rows = [line.split() for line in result.stdout.splitlines()
                if len(line.split()) >= 6 and line.split()[3].isdigit()
                and line.split()[4].endswith("%")]
        if not rows:
            raise Failure("Storage Box df did not report filesystem quota usage", transient=True)
        free_bytes = int(rows[-1][3]) * 1024
        quota_bytes = self.config.get("capacity", {}).get(
            "quotaBytes", self.config.get("quotaBytes", 1099511627776))
        if quota_bytes <= 0:
            raise Failure("Storage Box purchased quota must be positive")
        # ZFS's reported filesystem total can shrink while provider snapshots
        # retain data. Measure unavailable quota against the purchased capacity.
        used = round(100 * max(0, quota_bytes - free_bytes) / quota_bytes, 2)
        self.update(lambda data: data.update({"capacity": {
            "percent": used, "freeBytes": free_bytes, "quotaBytes": quota_bytes,
            "checkedAt": utcnow().isoformat(), "measurement": "free-quota-estimate",
        }}))
        self.transition("capacity", "critical" if used >= 85 else "warning" if used >= 70 else "ok",
                        "Storage Box occupied quota is approximately %.2f%%; "
                        "confirm provider-snapshot usage in the dashboard" % used)

    def monitor(self):
        failure = None
        try:
            snapshots = self.snapshots(complete=True)
            latest = {}
            for snapshot in snapshots:
                for scope in ["home", "services"]:
                    if scope not in snapshot.get("tags", []):
                        continue
                    key = snapshot["hostname"] + ":" + scope
                    if key not in latest or parsed_time(snapshot["time"]) > parsed_time(latest[key]):
                        latest[key] = snapshot["time"]
            def contacted(data):
                data.update({"observedComplete": latest,
                             "lastRepositoryContact": utcnow().isoformat()})
                data.setdefault("lastFailure", {}).pop("repository", None)
            self.update(contacted)
            self.transition("repository", "ok", "Repository access succeeded")
        except Failure as error:
            failure = error
            latest = self.update(lambda data: dict(data.get("observedComplete", {})))
            local = self.update(lambda data: dict(data.get("lastComplete", {})))
            for scope, complete in local.items():
                latest.setdefault(self.config["host"] + ":" + scope, complete["capturedAt"])
            if not error.transient:
                self.transition("repository", "critical", str(error))
        for host in {self.config["host"], self.config.get("peerHost") or self.config["host"]}:
            for scope, hours in [("services", 2), ("home", 12)]:
                recorded = latest.get(host + ":" + scope)
                age = (utcnow() - parsed_time(recorded)).total_seconds() if recorded else None
                overdue = age is None or age > hours * 3600
                self.transition(
                    "freshness:" + host + ":" + scope,
                    "warning" if overdue else "ok",
                    host + " " + scope + (" backup is overdue (no complete restore point)" if age is None
                    else " complete backup data age is %.1f hours (limit %d hours)" % (age / 3600, hours)),
                )
        if self.ssh:
            try:
                self.check_capacity()
            except Failure as error:
                if error.transient:
                    self.capacity_unavailable()
                else:
                    self.transition("capacity", "critical", str(error))
                failure = failure or error
        if self.config.get("inventory", {}).get("enabled"):
            self.inventory()
        def growth_review(data):
            first = data.get("firstCompleteAt")
            if not first or data.get("growthReviewReminder") or (utcnow() - parsed_time(first)).days < 30:
                return
            data["growthReviewReminder"] = utcnow().isoformat()
            data.setdefault("notifications", []).append({
                "title": "Review backup storage growth",
                "message": "The first month of backups is complete. Review deduplication, "
                           "compression, provider-snapshot usage and retained history before changing retention.",
                "priority": 3,
            })
        self.update(growth_review)
        self.notify()
        if failure:
            raise failure

    def inventory(self):
        specification = self.config["inventory"]
        covered = list(map(Path, specification.get("coveredPaths", [])))
        ignored = list(map(lambda entry: Path(entry["path"]),
                           specification.get("classifiedRegenerable", [])))
        observed, issues = [], []
        try:
            result = subprocess.run(
                ["systemctl", "list-units", "--type=service", "--all", "--no-legend", "--plain"],
                capture_output=True, text=True, timeout=30,
            )
            if result.returncode:
                issues.append("Cannot inspect system service state directories")
            else:
                units = [line.split()[0] for line in result.stdout.splitlines() if line.split()]
                for unit in units:
                    detail = subprocess.run(
                        ["systemctl", "show", "--value", "--property=StateDirectory", unit],
                        capture_output=True, text=True, timeout=10,
                    )
                    if detail.returncode:
                        issues.append("Cannot inspect " + unit)
                        continue
                    for value in detail.stdout.split():
                        # systemd StateDirectory values are relative to /var/lib.
                        value = value.split(":", 1)[0]
                        path = Path(value) if value.startswith("/") else Path("/var/lib") / value
                        if path.exists():
                            observed.append({"path": str(path), "service": unit})
            if shutil.which("docker"):
                containers = subprocess.run(["docker", "ps", "--all", "--quiet"],
                                            capture_output=True, text=True, timeout=30)
                if containers.returncode:
                    issues.append("Cannot inspect Docker persistent mounts")
                else:
                    for container in containers.stdout.split():
                        mounts = subprocess.run(
                            ["docker", "inspect", "--format", "{{json .Mounts}}", container],
                            capture_output=True, text=True, timeout=10,
                        )
                        if mounts.returncode:
                            issues.append("Cannot inspect container " + container)
                            continue
                        for mount in json.loads(mounts.stdout) or []:
                            if mount.get("Type") in ["bind", "volume"] and mount.get("Source"):
                                observed.append({"path": mount["Source"], "container": container,
                                                 "target": mount["Destination"]})
        except (OSError, ValueError, subprocess.TimeoutExpired):
            issues.append("Runtime state inventory is incomplete")
        def contained(path, roots):
            resolved = Path(path).resolve()
            return any(resolved == root.resolve() or root.resolve() in resolved.parents for root in roots)
        scaffolds = {Path(entry["path"]).resolve() for entry in specification.get("scaffolds", [])}
        checked = []
        for entry in observed:
            path = Path(entry["path"]).resolve()
            if path in scaffolds and path.is_dir():
                try:
                    checked.extend(dict(entry, path=str(child)) for child in path.iterdir())
                except OSError:
                    issues.append("Cannot inspect state directory scaffold " + entry["path"])
                    checked.append(entry)
            else:
                checked.append(entry)
        uncovered = [entry for entry in checked
                     if not contained(entry["path"], covered) and not contained(entry["path"], ignored)]
        self.update(lambda data: data.update({"inventory": {
            "checkedAt": utcnow().isoformat(), "observedPaths": observed,
            "uncoveredPaths": uncovered, "issues": issues,
            "classifiedRegenerable": specification.get("classifiedRegenerable", []),
        }}))
        self.transition("inventory", "warning" if uncovered or issues else "ok",
                        "Persistent service state coverage has %d unclassified paths and %d inspection issues" %
                        (len(uncovered), len(issues)))

    def restore_test(self, host, scope, target, includes):
        started = time.monotonic()
        destination = Path(target).absolute()
        if destination.is_symlink() or (destination.exists() and
                                        (not destination.is_dir() or any(destination.iterdir()))):
            raise Failure("Restore rehearsal requires a new or empty isolated directory")
        destination = destination.resolve()
        sources = [self.state]
        sources.extend(map(Path, self.config.get("inventory", {}).get("coveredPaths", [])))
        for specification in self.config["scopes"].values():
            sources.extend(map(Path, specification.get("paths", [])))
            for entry in specification.get("captures", []):
                sources.extend(map(Path, entry.get("paths", [])))
                for name in ["storagePath", "flakePath"]:
                    if entry.get(name):
                        sources.append(Path(entry[name]))
                for coordinated in entry.get("coordinated", []):
                    sources.extend(map(Path, coordinated.get("paths", [])))
        for source in sources:
            resolved = source.resolve()
            if destination == resolved or destination in resolved.parents or resolved in destination.parents:
                raise Failure("Restore target overlaps backup source or staging state")
        points = [point for point in self.snapshots(complete=True)
                  if point["hostname"] == host and scope in point.get("tags", [])]
        if not points:
            raise Failure("No complete restore point exists for that machine and scope")
        snapshot = max(points, key=lambda point: parsed_time(point["time"]))
        destination.mkdir(parents=True, exist_ok=True, mode=0o700)
        destination.chmod(0o700)
        arguments = ["restore", snapshot["id"], "--target", str(destination), "--verify"]
        for pattern in includes:
            arguments.extend(["--include", pattern])
        self.restic(*arguments)
        sqlite_count, archive_count, file_count, manifest_count = 0, 0, 0, 0
        for directory, directories, files in os.walk(destination, followlinks=False):
            directories[:] = [name for name in directories
                              if not (Path(directory) / name).is_symlink()]
            for name in files:
                path = Path(directory) / name
                if path.is_symlink() or not path.is_file():
                    continue
                file_count += 1
                with path.open("rb") as stream:
                    header = stream.read(16)
                if header == b"SQLite format 3\0":
                    try:
                        with sqlite3.connect(path.as_uri() + "?mode=ro", uri=True) as database:
                            if database.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
                                raise Failure("Restored SQLite database failed integrity verification")
                    except sqlite3.Error as error:
                        raise Failure("Restored SQLite database is unreadable") from error
                    sqlite_count += 1
                if header.startswith(b"PGDMP"):
                    result = subprocess.run(["pg_restore", "--list", str(path)],
                                            capture_output=True, text=True)
                    if result.returncode:
                        raise Failure("Restored PostgreSQL archive cannot be read by installed pg_restore")
                    archive_count += 1
                if name == "capture-manifest.json":
                    manifest = json.loads(path.read_text())
                    for entry in manifest["captures"]:
                        for metadata in entry.get("paths", []):
                            logical = Path(metadata["path"])
                            if not logical.is_absolute() or ".." in logical.parts:
                                raise Failure("Capture manifest contains an invalid source path")
                            restored = path.parent / "tree" / logical.relative_to("/")
                            if not restored.exists():
                                if includes:
                                    continue
                                raise Failure("Capture manifest source is missing from restore")
                            attributes = restored.stat()
                            if stat.S_IMODE(attributes.st_mode) != metadata["mode"]:
                                raise Failure("Restored capture permissions differ from recovery manifest")
                            if os.geteuid() == 0 and (attributes.st_uid, attributes.st_gid) != (metadata["uid"], metadata["gid"]):
                                raise Failure("Restored capture ownership differs from recovery manifest")
                        for database in entry.get("databases", []):
                            if "dump" in database and not (path.parent / database["dump"]).is_file() and not includes:
                                raise Failure("A database listed in the recovery manifest is missing")
                    manifest_count += 1
        if not file_count:
            raise Failure("Restore rehearsal did not restore any regular files")
        report = {"host": host, "scope": scope, "snapshotId": snapshot["id"],
                  "capturedAt": snapshot["time"], "partialSelection": bool(includes),
                  "target": str(destination), "seconds": round(time.monotonic() - started, 3),
                  "verifiedFiles": file_count, "verifiedSqliteDatabases": sqlite_count,
                  "readablePostgresArchives": archive_count, "captureManifests": manifest_count,
                  "applicationStartupVerified": False}
        def completed(data):
            data["lastRestoreRehearsal"] = report
            data.setdefault("lastFailure", {}).pop("restore-test:" + scope, None)
        self.update(completed)
        self.transition("restore-test:" + scope, "ok", scope + " restore rehearsal succeeded")
        print(json.dumps(report))

    def admin_restic(self, arguments):
        if arguments and arguments[0] == "--":
            arguments = arguments[1:]
        if not arguments:
            raise Failure("Supply a restic command after --")
        protected = ["--repo", "--repository-file", "--password-file", "--password-command",
                     "--option", "--insecure-no-password", "--insecure-tls", "--no-lock"]
        if any(argument.split("=", 1)[0] in protected
               or argument.startswith(("-r", "-p", "-o")) for argument in arguments):
            raise Failure("Repository, credentials, locking and SSH options are fixed by backup configuration")
        self.credentials()
        return subprocess.run(self.base + arguments, env=self.env).returncode


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    commands = parser.add_subparsers(dest="command", required=True)
    backup = commands.add_parser("backup")
    backup.add_argument("--scope", required=True, choices=["home", "services"])
    commands.add_parser("status")
    maintain = commands.add_parser("maintain")
    maintain.add_argument("--dry-run", action="store_true")
    commands.add_parser("rehearsal-reminder")
    commands.add_parser("monitor")
    commands.add_parser("inventory")
    restore = commands.add_parser("restore-test")
    restore.add_argument("--host", required=True)
    restore.add_argument("--scope", required=True, choices=["home", "services"])
    restore.add_argument("--target", required=True)
    restore.add_argument("--include", action="append", default=[])
    restic = commands.add_parser("restic")
    restic.add_argument("arguments", nargs=argparse.REMAINDER)
    arguments = parser.parse_args()
    try:
        runner = Runner(json.loads(Path(arguments.config).read_text()))
        returncode = 0
        lock_name = "monitor.lock" if arguments.command in ["monitor", "status", "inventory", "rehearsal-reminder"] else "operation.lock"
        with (runner.state / lock_name).open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise Failure("Another local backup operation is running", transient=True) from error
            if arguments.command == "backup":
                runner.backup(arguments.scope)
            elif arguments.command == "status":
                print(json.dumps(runner.update(lambda data: dict(data))))
            elif arguments.command == "maintain":
                runner.maintain(arguments.dry_run)
            elif arguments.command == "rehearsal-reminder":
                runner.rehearsal_reminder()
            elif arguments.command == "monitor":
                runner.monitor()
            elif arguments.command == "inventory":
                runner.inventory()
                print(json.dumps(runner.update(lambda data: data["inventory"])))
            elif arguments.command == "restore-test":
                runner.restore_test(arguments.host, arguments.scope, arguments.target, arguments.include)
            elif arguments.command == "restic":
                returncode = runner.admin_restic(arguments.arguments)
        if arguments.command == "backup" and runner.config.get("gotify"):
            with runner.phase("Delivering backup notifications"):
                runner.notify()
        else:
            runner.notify()
    except (Failure, OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
        if not isinstance(error, Failure):
            if isinstance(error, subprocess.TimeoutExpired):
                error = Failure("External backup command timed out", transient=True)
            elif isinstance(error, OSError):
                error = Failure("Backup operation cannot access runtime credentials or local state (errno %s)" % error.errno)
            else:
                error = Failure("Invalid backup configuration or repository metadata")
        if "runner" in locals():
            key = ("repository" if arguments.command == "monitor" else
                   arguments.command + ":" + getattr(arguments, "scope", "repository"))
            try:
                runner.update(lambda data: data.setdefault("lastFailure", {}).update({
                    key: {"at": utcnow().isoformat(), "message": str(error),
                          "transient": error.transient},
                }))
                if not error.transient:
                    runner.transition(key, "critical", str(error))
                runner.notify()
            except OSError:
                print("Cannot persist backup health in local state", file=sys.stderr)
        print(str(error), file=sys.stderr)
        return 75 if error.transient else 1
    return returncode


if __name__ == "__main__":
    sys.exit(main())
