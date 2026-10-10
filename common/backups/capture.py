"""Create recoverable local service captures before any off-machine upload.

Only ``prepare`` and ``CaptureError`` are public. System commands are located
through PATH, supplied by the NixOS backup unit. Staging must be root-owned and
private; it is reusable across runs so large file captures can be preseeded.
"""
from __future__ import annotations

from contextlib import closing, contextmanager
import json
import fnmatch
import fcntl
import os
from pathlib import Path
import stat
import signal
import shutil
import sqlite3
import subprocess
import select
import sys
import tempfile
import uuid
import time
from urllib.parse import quote, urlencode
from urllib.request import urlopen
from urllib.error import URLError


class CaptureError(RuntimeError):
    """A capture is incomplete; its data must not become a complete restore point."""


def _run(args, *, timeout=None, stdout=None, accepted_codes=(0,)):
    try:
        result = subprocess.run(args, check=False, timeout=timeout, stdout=stdout if stdout is not None else subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode not in accepted_codes:
            raise subprocess.CalledProcessError(result.returncode, args, result.stdout, result.stderr)
        return result.stdout
    except (OSError, subprocess.SubprocessError) as error:
        detail = getattr(error, "stderr", b"") or b""
        message = detail.decode(errors="replace")[-2000:] or str(error)
        raise CaptureError(f"{args[0]} failed: {message}") from error


def _run_service_command(unit, action, *, timeout):
    args = _unit_command(unit, action)
    try:
        # runuser -u USER -- PROGRAM keeps its child in the same session; only
        # shell -c mode creates another one. Isolate this command family so a
        # timeout cannot leave a systemctl child submitting STOP after recovery.
        # setsid changes the process group, not the guardian's systemd cgroup:
        # PID 1 still kills the whole family if the guardian itself dies.
        with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              start_new_session=True) as process:
            try:
                output, error_output = process.communicate(timeout=timeout)
            except BaseException:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()
                raise
            if process.returncode:
                raise subprocess.CalledProcessError(process.returncode, args, output, error_output)
            return output
    except (OSError, subprocess.SubprocessError) as error:
        detail = getattr(error, "stderr", b"") or b""
        message = detail.decode(errors="replace")[-2000:] or str(error)
        raise CaptureError(f"{args[0]} failed: {message}") from error


def _paths(entry):
    sources = []
    for raw in entry.get("paths", []):
        source = Path(raw)
        if not source.is_absolute():
            raise CaptureError(f"Source path must be absolute: {source}")
        if not source.exists():
            if entry.get("optional", False):
                continue
            raise CaptureError(f"Required source is missing: {source}")
        sources.append(source)
    return sources



def _remove(path):
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink(missing_ok=True)


def _trim_staging(scope_config, staging):
    selected = []
    names = set()
    for entry in scope_config.get("captures", []):
        name = entry["name"]
        if not name or any(character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" for character in name) or name in names:
            raise CaptureError(f"Capture name must be unique and contain letters, digits, '-' or '_': {name}")
        names.add(name)
        selected.extend(_paths(entry))
        for coordinated in entry.get("coordinated", []):
            selected.extend(_paths(coordinated))
        if entry.get("kind") == "nix":
            selected.append(Path(entry["flakePath"]))
    tree = staging / "tree"
    roots = [tree / source.relative_to("/") for source in selected]
    def trim(directory):
        for child in directory.iterdir():
            if any(child == root or root in child.parents for root in roots):
                continue
            if any(child in root.parents for root in roots) and child.is_dir() and not child.is_symlink():
                trim(child)
            else:
                _remove(child)
    if tree.exists():
        if tree.is_symlink():
            raise CaptureError("Staging tree must not be a symlink")
        trim(tree)
    for group, allowed in (("databases", {entry["name"] for entry in scope_config.get("captures", []) if entry["kind"] in ("postgres", "victoria")}), ("recovery", {entry["name"] for entry in scope_config.get("captures", []) if entry["kind"] == "nix"})):
        directory = staging / group
        if directory.exists():
            for child in directory.iterdir():
                if child.name not in allowed:
                    _remove(child)


def _destination(source, staging):
    tree = staging / "tree"
    tree.mkdir(parents=True, exist_ok=True)
    if tree.is_symlink():
        raise CaptureError("Staging tree must not be a symlink")
    destination = tree / source.relative_to("/")
    # Previously captured directory symlinks must never redirect subsequent
    # writes out of the private staging tree.
    parent = tree
    for component in source.relative_to("/").parts[:-1]:
        parent = parent / component
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            _remove(parent)
        parent.mkdir(exist_ok=True)
    if destination.is_symlink():
        destination.unlink()
    return destination

def _copy(source, staging, excludes=(), *, timeout=None, preseed=False):
    if staging.resolve().is_relative_to(source.resolve()):
        raise CaptureError(f"Source must not contain the staging directory: {source}")
    destination = _destination(source, staging)
    args = ["rsync", "--archive", "--hard-links", "--acls", "--xattrs", "--numeric-ids", "--modify-window=-1", "--delete", "--delete-excluded", "--exclude=.direnv/"]
    args += [f"--exclude={pattern}" for pattern in excludes]
    # A service StateDirectory is often a /var/lib/private symlink. Dereference
    # only the selected root; symlinks *inside* it keep their original meaning.
    if source.is_dir():
        destination.mkdir(parents=True, exist_ok=True)
        args += [str(source) + "/", str(destination) + "/"]
    else:
        args += [str(source.resolve()) if source.is_symlink() else str(source), str(destination)]
    _run(args, timeout=timeout, accepted_codes=(0, 24) if preseed else (0,))
    metadata = source.stat()
    return {"path": str(source), "resolvedSource": str(source.resolve()), "uid": metadata.st_uid, "gid": metadata.st_gid, "mode": stat.S_IMODE(metadata.st_mode)}



def _unit_command(unit, action):
    command = ["systemctl", action, unit["name"]]
    if unit.get("type", "system") == "user":
        uid = str(unit["uid"])
        command = ["runuser", "-u", unit["user"], "--", "env", "XDG_RUNTIME_DIR=/run/user/" + uid, "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/" + uid + "/bus", "systemctl", "--user", action, unit["name"]]
    return command



def _capture_units(entry):
    units = list(entry.get("units", []))
    for query in entry.get("discoverUnits", []):
        if query.get("type", "system") == "user" and not Path(f"/run/user/{query['uid']}/bus").exists():
            continue
        pattern = query["pattern"]
        command = _unit_command({**query, "name": pattern}, "list-units")
        output = _run([*command, "--all", "--plain", "--no-legend", "--type=service"])
        for line in output.decode().splitlines():
            fields = line.split()
            if fields and fnmatch.fnmatchcase(fields[0], pattern):
                units.append({**{key: value for key, value in query.items() if key != "pattern"}, "name": fields[0]})
    unique = {}
    for unit in units:
        key = (unit.get("type", "system"), unit.get("uid"), unit["name"])
        unique[key] = unit
    return list(unique.values())

def _remaining(deadline):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise CaptureError("Local capture exceeded the service interruption budget")
    return remaining


def _launch_service_watchdog(plan, timeout):
    _run(["systemd-run", "--quiet", "--collect", "--service-type=exec",
          "--unit=machine-backup-services-" + uuid.uuid4().hex,
          "--property=Restart=on-failure", "--property=RestartSec=1s",
          "--property=StartLimitIntervalSec=0",
          "--property=RestartForceExitStatus=SIGTERM SIGINT",
          "--property=KillMode=control-group",
          "--setenv=PATH=" + os.environ["PATH"], "--", sys.executable,
          str(Path(__file__).resolve()), "--service-watchdog", str(plan)], timeout=timeout)


def _check_service_recovery(units, directory):
    if not directory.exists():
        return
    if directory.is_symlink() or directory.stat().st_uid != os.geteuid():
        raise CaptureError("Service watchdog directory must be private and owned by the backup user")
    selected = {(unit.get("type", "system"), unit.get("uid"), unit["name"]) for unit in units}
    for plan_path in directory.glob("capture-*/plan.json"):
        if plan_path.with_suffix(".done").exists():
            continue
        try:
            plan = json.loads(plan_path.read_text())
        except FileNotFoundError:
            continue
        claimed = {(unit.get("type", "system"), unit.get("uid"), unit["name"]) for unit in plan["units"]}
        if not selected.intersection(claimed):
            continue
        # A failed launch can leave a lease without a running guardian. Rearm
        # recovery only once STOP is forbidden (release requested or parent dead).
        try:
            parent_alive = _process_identity(plan["parent"]["pid"])["startTime"] == plan["parent"]["startTime"]
        except (FileNotFoundError, ProcessLookupError):
            parent_alive = False
        if plan_path.with_suffix(".release").exists() or not parent_alive:
            plan_path.with_suffix(".release").write_text("resume\n")
            _launch_service_watchdog(plan_path, timeout=5)
            wait_until = time.monotonic() + 1
            while not plan_path.with_suffix(".done").exists() and time.monotonic() < wait_until:
                time.sleep(0.01)
        if not plan_path.with_suffix(".done").exists():
            raise CaptureError("Previous managed-service recovery is still pending; retry after it completes")


@contextmanager
def _paused(units, timeout_seconds, staging):
    directory = staging.parent / "service-watchdogs"
    # A retry must not mistake a service awaiting old recovery for an originally
    # inactive service: that old guardian could start it during the new copy.
    _check_service_recovery(units, directory)
    active = []
    for unit in units:
        if unit.get("type", "system") == "user" and not Path(f"/run/user/{unit['uid']}/bus").exists():
            # No bus means this user manager cannot have the declared unit
            # running. Do not create a login session just to capture its files.
            continue
        result = subprocess.run(_unit_command(unit, "is-active"), stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=10)
        if result.returncode == 0:
            active.append(unit)
        elif result.returncode not in (3, 4):
            raise CaptureError(f"Cannot determine availability of {unit['name']}")
    deadline = time.monotonic() + timeout_seconds
    # Reserve part of the interruption budget for availability restoration.
    capture_deadline = deadline - min(10.0, timeout_seconds / 4)
    if not active:
        yield capture_deadline
        _remaining(capture_deadline)
        return
    if not hasattr(os, "pidfd_open"):
        raise CaptureError("Safe service interruption requires Linux pidfd support")
    if directory.is_symlink():
        raise CaptureError("Service watchdog directory must not be a symlink")
    directory.mkdir(parents=True, mode=0o700, exist_ok=True)
    if directory.stat().st_uid != os.geteuid():
        raise CaptureError("Service watchdog directory is owned by another user")
    directory.chmod(0o700)
    for old in directory.iterdir():
        if old.is_dir() and (old / "plan.done").exists() and time.time() - old.stat().st_mtime > 60:
            shutil.rmtree(old)
    control = Path(tempfile.mkdtemp(prefix="capture-", dir=directory))
    plan = control / "plan.json"
    _control_json(plan, {"parent": _process_identity(os.getpid()), "units": active,
                         "deadline": capture_deadline, "recoveryDeadline": deadline})
    try:
        # The guardian owns STOP too: a descheduled/orphaned capture cannot
        # submit a late stop after independent recovery has already started.
        _launch_service_watchdog(plan, timeout=min(5.0, _remaining(capture_deadline)))
        while not plan.with_suffix(".ready").exists():
            if plan.with_suffix(".done").exists():
                raise CaptureError("Managed services could not be paused")
            _remaining(capture_deadline)
            time.sleep(0.01)
        yield capture_deadline
        _remaining(capture_deadline)
    finally:
        plan.with_suffix(".release").write_text("resume\n")
        # Keep the durable lease until the independent unit acknowledges every
        # restart. Failed starts keep retrying even after this capture fails.
        while not plan.with_suffix(".done").exists() and time.monotonic() < max(deadline, capture_deadline + 1):
            time.sleep(0.01)
        if not plan.with_suffix(".done").exists():
            raise CaptureError("Service watchdog has not acknowledged service recovery")
        result = json.loads(plan.with_suffix(".done").read_text())
        shutil.rmtree(control)
        if result["failures"]:
            raise CaptureError("Service capture failed: " + "; ".join(result["failures"]))


def _service_watchdog(plan_path):
    """Own managed-unit interruption outside the backup job's cgroup."""
    try:
        with (plan_path.parent / "recovery.lock").open("a") as lock:
            # Retried launch requests may create more than one supervised unit.
            # Only one may act on the lease. Duplicates leave its existing owner
            # supervised by PID 1 instead of accumulating across failed retries.
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return
            _recover_service_lease(plan_path)
    except FileNotFoundError:
        if plan_path.parent.exists():
            raise


def _recover_service_lease(plan_path):
    try:
        plan = json.loads(plan_path.read_text())
    except FileNotFoundError:
        return
    if plan_path.with_suffix(".done").exists():
        return
    parent_handle = None
    try:
        try:
            parent_handle = os.pidfd_open(plan["parent"]["pid"])
            if _process_identity(plan["parent"]["pid"])["startTime"] != plan["parent"]["startTime"]:
                os.close(parent_handle)
                parent_handle = None
        except (FileNotFoundError, ProcessLookupError):
            pass
        poller = select.poll()
        if parent_handle is not None:
            poller.register(parent_handle, select.POLLIN)
        def released():
            return (parent_handle is None or bool(poller.poll(0))
                    or plan_path.with_suffix(".release").exists()
                    or time.monotonic() >= plan["deadline"])
        failures = []
        ready = plan_path.with_suffix(".ready")
        if not ready.exists():
            try:
                for unit in plan["units"]:
                    if released():
                        raise CaptureError("Service capture was interrupted before all units stopped")
                    _run_service_command(unit, "stop", timeout=_remaining(plan["deadline"]))
                if not released():
                    _control_json(ready, {})
            except CaptureError as error:
                failures.append(str(error))
        while ready.exists() and not released():
            time.sleep(0.01)
        pending = list(reversed(plan["units"]))
        while pending:
            retry = []
            for unit in pending:
                try:
                    # Bound each attempt so one broken unit cannot prevent the
                    # other services from recovering; PID 1 supervises retries.
                    _run_service_command(unit, "start", timeout=min(5.0, max(0.1, plan["recoveryDeadline"] - time.monotonic())))
                except CaptureError as error:
                    print(f"Service recovery will retry {unit['name']}: {error}", file=sys.stderr, flush=True)
                    retry.append(unit)
            pending = retry
            if pending:
                time.sleep(0.1 if time.monotonic() < plan["recoveryDeadline"] else 1)
        _control_json(plan_path.with_suffix(".done"), {"failures": failures})
    finally:
        if parent_handle is not None:
            os.close(parent_handle)


def _files(entry, staging, timeout_seconds):
    sources = _paths(entry)
    excludes = entry.get("excludes", [])
    if sources and (entry.get("units") or entry.get("discoverUnits")):
        # Preseed bulk state while the service is running; only its incremental
        # final copy consumes the downtime budget.
        for source in sources:
            _copy(source, staging, excludes, preseed=True)
        with _paused(_capture_units(entry), timeout_seconds, staging) as deadline:
            return [_copy(source, staging, excludes, timeout=_remaining(deadline)) for source in sources]
    return [_copy(source, staging, excludes) for source in sources]



def _sqlite_files(source, *, deadline=None):
    candidates = [source]
    if source.is_dir():
        candidates = []
        for directory, directories, files in os.walk(source, followlinks=False):
            if deadline is not None:
                _remaining(deadline)
            directories[:] = [name for name in directories if name != ".direnv"]
            candidates.extend(Path(directory) / name for name in files)
    databases = []
    for path in candidates:
        if deadline is not None:
            _remaining(deadline)
        if path.is_symlink() or not path.is_file():
            continue
        try:
            with path.open("rb") as stream:
                if stream.read(16) == b"SQLite format 3\0":
                    databases.append(path)
        except OSError as error:
            raise CaptureError(f"Cannot inspect SQLite candidate {path}: {error}") from error
    return databases


def _sqlite_backup(database, staging, *, deadline=None):
    destination = _destination(database, staging)
    temporary = destination.with_name(destination.name + ".backup-new")
    temporary.unlink(missing_ok=True)
    if deadline is None:
        deadline = time.monotonic() + 600
    def progress(status, remaining, total):
        _remaining(deadline)
    try:
        # Read-only URI is deliberate: never initialize or migrate source state.
        with closing(sqlite3.connect(database.as_uri() + "?mode=ro", uri=True, timeout=min(10.0, _remaining(deadline)))) as source_db, closing(sqlite3.connect(temporary, timeout=min(10.0, _remaining(deadline)))) as target_db:
            source_db.set_progress_handler(lambda: int(time.monotonic() >= deadline), 1000)
            target_db.set_progress_handler(lambda: int(time.monotonic() >= deadline), 1000)
            source_db.backup(target_db, pages=1024, progress=progress, sleep=0.1)
            target_db.execute("PRAGMA journal_mode=DELETE")
            if target_db.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
                raise CaptureError(f"SQLite capture failed integrity verification: {database}")
            metadata = {"path": str(database), "sqliteVersion": sqlite3.sqlite_version, "userVersion": target_db.execute("PRAGMA user_version").fetchone()[0]}
        _remaining(deadline)
        shutil.copystat(database, temporary)
        source_stat = database.stat()
        if os.geteuid() == 0:
            os.chown(temporary, source_stat.st_uid, source_stat.st_gid)
        temporary.replace(destination)
        _remaining(deadline)
        return metadata
    except sqlite3.Error as error:
        raise CaptureError(f"SQLite capture failed: {database}: {error}") from error
    finally:
        temporary.unlink(missing_ok=True)



def _process_identity(pid):
    text = Path(f"/proc/{pid}/stat").read_text()
    fields = text.rsplit(")", 1)[1].split()
    uid = next(line.split()[1] for line in Path(f"/proc/{pid}/status").read_text().splitlines() if line.startswith("Uid:"))
    return {"pid": int(pid), "startTime": int(fields[19]), "state": fields[0], "parentPid": int(fields[1]), "uid": int(uid)}


def _backup_ancestors():
    excluded, pid = set(), os.getpid()
    while pid and pid not in excluded:
        excluded.add(pid)
        try:
            pid = _process_identity(pid)["parentPid"]
        except FileNotFoundError:
            break
    return excluded


def _source_writer_path(raw, roots):
    if not raw.startswith("/"):
        return False
    path = Path(raw.removesuffix(" (deleted)")).resolve()
    return any(path.is_relative_to(root) if directory else path == root or str(path) in (str(root) + "-wal", str(root) + "-journal", str(root) + "-shm") for root, directory in roots)


def _open_writers(sources, uid):
    roots = [(source.resolve(), source.is_dir()) for source in sources]
    ancestors = _backup_ancestors()
    writers = []
    for entry in list(Path("/proc").iterdir()):
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        try:
            identity = _process_identity(pid)
            if identity["uid"] != uid or identity["state"] in ("T", "t", "Z"):
                continue
            writable = False
            for descriptor in list(Path(f"/proc/{pid}/fd").iterdir()):
                try:
                    target = os.readlink(descriptor)
                    if not _source_writer_path(target, roots):
                        continue
                    flags = next(line.split()[1] for line in Path(f"/proc/{pid}/fdinfo/{descriptor.name}").read_text().splitlines() if line.startswith("flags:"))
                    if (int(flags, 8) & os.O_ACCMODE) in (os.O_WRONLY, os.O_RDWR):
                        writable = True
                        break
                except FileNotFoundError:
                    continue
            # A process can close its descriptor after creating a shared writable
            # mapping. Such a mapping still makes it a writer of the selected data.
            if not writable:
                for line in Path(f"/proc/{pid}/maps").read_text().splitlines():
                    fields = line.split(maxsplit=5)
                    if len(fields) == 6 and fields[1][1:2] == "w" and fields[1][3:4] == "s" and _source_writer_path(fields[5], roots):
                        writable = True
                        break
            if writable:
                if pid in ancestors:
                    raise CaptureError(f"Backup process or ancestor {pid} holds writable source data; unsafe to suspend")
                if _process_identity(pid)["startTime"] == identity["startTime"]:
                    writers.append(identity)
        except (FileNotFoundError, ProcessLookupError):
            continue
        except PermissionError as error:
            raise CaptureError(f"Cannot safely inspect writer {pid}") from error
    return writers


def _control_json(path, value):
    temporary = path.with_name(path.name + ".new")
    temporary.write_text(json.dumps(value))
    temporary.chmod(0o600)
    temporary.replace(path)


def _resume_watchdog(plan_path):
    """PID 1 runs this process in a separate unit from the backup being watched."""
    try:
        plan = json.loads(plan_path.read_text())
    except FileNotFoundError:
        # A restart can arrive after its lease was already acknowledged and
        # removed. It has nothing left to resume and must not restart again.
        return
    ready = plan_path.with_suffix(".ready")
    handles, parent_handle = [], None
    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, _terminated)
    try:
        previously_armed = ready.exists()
        claimed = json.loads(ready.read_text())["writers"] if previously_armed else plan["writers"]
        plan_path.with_suffix(".done").unlink(missing_ok=True)
        for expected in claimed:
            try:
                handle = os.pidfd_open(expected["pid"])
                current = _process_identity(expected["pid"])
                if current["startTime"] != expected["startTime"] or current["uid"] != expected["uid"]:
                    os.close(handle)
                    continue
                # On the first arm, a process already stopped by somebody else
                # is excluded. A restarted watchdog retains its original lease.
                if not previously_armed and current["state"] in ("T", "t"):
                    os.close(handle)
                    continue
                handles.append((expected, handle))
            except (FileNotFoundError, ProcessLookupError):
                continue
        try:
            parent_handle = os.pidfd_open(plan["parent"]["pid"])
            if _process_identity(plan["parent"]["pid"])["startTime"] != plan["parent"]["startTime"]:
                os.close(parent_handle)
                parent_handle = None
        except (FileNotFoundError, ProcessLookupError):
            parent_handle = None
        _control_json(ready, {"writers": [expected for expected, handle in handles]})
        poller = select.poll()
        if parent_handle is not None:
            poller.register(parent_handle, select.POLLIN)
        while parent_handle is not None and plan_path.exists() and not plan_path.with_suffix(".release").exists():
            if poller.poll(20):
                break
            if time.monotonic() >= plan["deadline"]:
                # The parent can be descheduled between its deadline check
                # and STOP. Keep the lease until it relinquishes that ability
                # or dies, including if a late STOP follows our first CONT.
                for expected, handle in handles:
                    try:
                        current = _process_identity(expected["pid"])
                        if current["startTime"] == expected["startTime"] and current["state"] in ("T", "t"):
                            signal.pidfd_send_signal(handle, signal.SIGCONT)
                    except (FileNotFoundError, ProcessLookupError):
                        pass
    finally:
        failures = []
        for expected, handle in handles:
            try:
                signal.pidfd_send_signal(handle, signal.SIGCONT)
            except ProcessLookupError:
                pass
            except OSError as error:
                failures.append(f"Cannot resume {expected['pid']}: {error}")
            finally:
                os.close(handle)
        if parent_handle is not None:
            os.close(parent_handle)
        try:
            if plan_path.exists():
                _control_json(plan_path.with_suffix(".done"), {"failures": failures})
        except FileNotFoundError:
            if plan_path.parent.exists():
                raise
        if failures:
            raise CaptureError("; ".join(failures))


def _wait_stopped(expected, deadline):
    while True:
        _remaining(deadline)
        try:
            current = _process_identity(expected["pid"])
            if current["startTime"] != expected["startTime"]:
                raise CaptureError("Writer identity changed during suspension")
            tasks = list(Path(f"/proc/{expected['pid']}/task").glob("*/stat"))
            if tasks and all(task.read_text().rsplit(")", 1)[1].split()[0] in ("T", "t") for task in tasks):
                return
        except FileNotFoundError:
            raise CaptureError("Writer exited during suspension; retry capture")
        time.sleep(0.005)


@contextmanager
def _suspended_writers(entry, staging, deadline):
    if not entry.get("pauseOpenWriters"):
        yield []
        return
    if not hasattr(os, "pidfd_open") or not hasattr(signal, "pidfd_send_signal"):
        raise CaptureError("Safe writer suspension requires Linux pidfd support")
    sources = _paths(entry)
    uid = int(entry["writerUid"])
    writers = _open_writers(sources, uid)
    if not writers:
        yield []
        _remaining(deadline)
        if _open_writers(sources, uid):
            raise CaptureError("A new source writer appeared during capture; retry")
        return
    directory = Path(entry.get("watchdogDirectory", staging.parent / "writer-watchdogs"))
    if directory.is_symlink():
        raise CaptureError("Writer watchdog directory must not be a symlink")
    directory.mkdir(parents=True, mode=0o700, exist_ok=True)
    if directory.stat().st_uid != os.geteuid():
        raise CaptureError("Writer watchdog directory is owned by another user")
    directory.chmod(0o700)
    for old in directory.iterdir():
        if old.is_dir() and (old / "plan.done").exists() and time.time() - old.stat().st_mtime > 60:
            shutil.rmtree(old)
    control = Path(tempfile.mkdtemp(prefix="capture-", dir=directory))
    plan = control / "plan.json"
    handles, stopped = [], []
    armed = False
    try:
        for expected in writers:
            handle = os.pidfd_open(expected["pid"])
            handles.append((expected, handle))
            if _process_identity(expected["pid"])["startTime"] != expected["startTime"]:
                raise CaptureError("Writer identity changed before suspension")
        _control_json(plan, {"parent": _process_identity(os.getpid()), "writers": writers, "deadline": deadline})
        unit = "machine-backup-writers-" + uuid.uuid4().hex
        # setsid alone would stay in the backup's cgroup and die with it.
        # PID 1 owns this watcher separately, including on backup SIGKILL.
        launch_timeout = min(5.0, _remaining(deadline))
        # A timed-out launch request may already have started its unit. Release
        # that possible guardian too; retain its plan until it acknowledges.
        armed = True
        _run(["systemd-run", "--quiet", "--collect", "--service-type=exec", "--unit=" + unit, "--property=Restart=on-failure", "--property=RestartSec=1s", "--", sys.executable, str(Path(__file__).resolve()), "--resume-watchdog", str(plan)], timeout=launch_timeout)
        ready = plan.with_suffix(".ready")
        arm_deadline = min(deadline, time.monotonic() + 5)
        while not ready.exists():
            _remaining(arm_deadline)
            time.sleep(0.01)
        claimed = json.loads(ready.read_text())["writers"]
        if {(writer["pid"], writer["startTime"]) for writer in claimed} != {(writer["pid"], writer["startTime"]) for writer in writers}:
            raise CaptureError("Writer exited or was already stopped while watchdog armed; retry")
        for expected, handle in handles:
            _remaining(deadline)
            signal.pidfd_send_signal(handle, signal.SIGSTOP)
            stopped.append((expected, handle))
        for expected, handle in stopped:
            _wait_stopped(expected, deadline)
        if _open_writers(sources, uid):
            raise CaptureError("A new source writer appeared while suspending; retry")
        yield writers
        _remaining(deadline)
        for expected, handle in stopped:
            current = _process_identity(expected["pid"])
            if current["startTime"] != expected["startTime"] or current["state"] not in ("T", "t"):
                raise CaptureError("A source writer resumed before capture completed; retry")
        if _open_writers(sources, uid):
            raise CaptureError("A new source writer appeared during capture; retry")
    finally:
        failures = []
        for expected, handle in stopped:
            try:
                signal.pidfd_send_signal(handle, signal.SIGCONT)
            except ProcessLookupError:
                pass
            except (OSError, CaptureError) as error:
                failures.append(f"Cannot resume writer {expected['pid']}: {error}")
        if armed:
            plan.with_suffix(".release").write_text("resume\n")
            release_deadline = time.monotonic() + 3
            while not plan.with_suffix(".done").exists() and time.monotonic() < release_deadline:
                time.sleep(0.01)
            if plan.with_suffix(".done").exists():
                failures.extend(json.loads(plan.with_suffix(".done").read_text())["failures"])
                shutil.rmtree(control)
            else:
                failures.append("Writer watchdog did not acknowledge resumption")
        else:
            shutil.rmtree(control)
        for expected, handle in handles:
            os.close(handle)
        if failures:
            raise CaptureError("Writer resumption failed: " + "; ".join(failures))


def _sqlite(entry, staging, timeout_seconds):
    sources = _paths(entry)
    def materialize(*, preseed=False, deadline=None):
        details, databases = [], []
        for source in sources:
            captured = _sqlite_files(source, deadline=deadline)
            excludes = list(entry.get("excludes", []))
            if source.is_dir():
                for database in captured:
                    pattern = "/" + database.relative_to(source).as_posix()
                    excludes.extend([pattern, pattern + "-wal", pattern + "-shm", pattern + "-journal"])
                details.append(_copy(source, staging, excludes, timeout=_remaining(deadline) if deadline is not None else None, preseed=preseed))
            elif source not in captured:
                details.append(_copy(source, staging, excludes, timeout=_remaining(deadline) if deadline is not None else None, preseed=preseed))
            else:
                source_stat = source.stat()
                details.append({"path": str(source), "resolvedSource": str(source.resolve()), "uid": source_stat.st_uid, "gid": source_stat.st_gid, "mode": stat.S_IMODE(source_stat.st_mode)})
            if not preseed:
                databases.extend(_sqlite_backup(database, staging, deadline=deadline) for database in captured)
        return {"paths": details, "databases": databases}
    if sources and (entry.get("units") or entry.get("discoverUnits") or entry.get("pauseOpenWriters")):
        # Configs, attachments and database references must share the same
        # quiescent interval. A native DB backup alone does not make earlier
        # copies of associated mutable files coherent with that database.
        materialize(preseed=True)
        with _paused(_capture_units(entry), timeout_seconds, staging) as deadline:
            with _suspended_writers(entry, staging, deadline) as writers:
                result = materialize(deadline=deadline)
                result["pausedOpenWriters"] = writers
            return result
    return materialize()


def _postgres_command(entry, executable, database=None):
    # A URI keeps unusual database names from being interpreted as conninfo.
    connection = "postgresql:///" + quote(database or entry.get("database", "postgres"), safe="") + "?" + urlencode({"host": entry.get("socket", "/run/postgresql"), "port": entry.get("port", 5432)})
    command = [executable, "--dbname=" + connection]
    if entry.get("user"):
        command = ["runuser", "-u", entry["user"], "--", *command]
    return command


def _postgres_query(entry, statement, database=None, *, timeout=None):
    output = _run([*_postgres_command(entry, "psql", database), "--no-psqlrc", "--tuples-only", "--no-align", "--set=ON_ERROR_STOP=1", "--command=" + statement], timeout=timeout)
    try:
        return json.loads(output)
    except (ValueError, TypeError) as error:
        raise CaptureError("Invalid PostgreSQL inventory output") from error


def _postgres_dump(entry, database, destination, *, timeout=None):
    # Root opens the target: the postgres account need not read private staging.
    temporary = destination.with_name(destination.name + ".new")
    try:
        with temporary.open("wb") as output:
            _run([*_postgres_command(entry, "pg_dump", database), "--format=custom", "--compress=none", "--create"], timeout=timeout, stdout=output)
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def _postgres(entry, staging, timeout_seconds):
    destination = staging / "databases" / entry["name"]
    destination.mkdir(parents=True, exist_ok=True)
    databases = _postgres_query(entry, "SELECT coalesce(json_agg(row_to_json(d)), '[]'::json) FROM (SELECT datname AS name, pg_get_userbyid(datdba) AS owner, pg_encoding_to_char(encoding) AS encoding, datcollate AS collate, datctype AS ctype, datistemplate AS template, datallowconn AS allows_connections FROM pg_database WHERE datname != 'template0' ORDER BY datname) d")
    if any(not database["allows_connections"] for database in databases):
        raise CaptureError("A PostgreSQL database disallows connections; explicit recovery coverage is required")
    globals_path = destination / "globals.sql"
    with globals_path.open("wb") as output:
        # pg_dumpall uses --database rather than --dbname.
        command = _postgres_command(entry, "pg_dumpall")
        command = [argument.replace("--dbname=", "--database=", 1) for argument in command]
        _run([*command, "--globals-only"], stdout=output)
    server = _postgres_query(entry, "SELECT json_build_object('version', current_setting('server_version'), 'versionNumber', current_setting('server_version_num'))")
    tablespaces = _postgres_query(entry, "SELECT coalesce(json_agg(row_to_json(t)), '[]'::json) FROM (SELECT spcname AS name, pg_get_userbyid(spcowner) AS owner, pg_tablespace_location(oid) AS location FROM pg_tablespace ORDER BY spcname) t")
    file_details, captured_names, database_details = [], set(), []
    indexed = {database["name"]: (index, database) for index, database in enumerate(databases)}
    for coordinated in entry.get("coordinated", []):
        name = coordinated["database"]
        if name not in indexed:
            raise CaptureError(f"Coordinated service database is missing: {name}")
        index, database = indexed[name]
        sources = _paths(coordinated)
        for source in sources:
            _copy(source, staging, coordinated.get("excludes", []), preseed=True)
        dump_path = destination / f"database-{index:03d}.dump"
        with _paused(_capture_units(coordinated), timeout_seconds, staging) as deadline:
            _postgres_dump(entry, name, dump_path, timeout=_remaining(deadline))
            file_details.extend(_copy(source, staging, coordinated.get("excludes", []), timeout=_remaining(deadline)) for source in sources)
        captured_names.add(name)
    for index, database in enumerate(databases):
        name = database["name"]
        dump_path = destination / f"database-{index:03d}.dump"
        if name not in captured_names:
            _postgres_dump(entry, name, dump_path)
        extensions = _postgres_query(entry, "SELECT coalesce(json_agg(row_to_json(e)), '[]'::json) FROM (SELECT extname AS name, extversion AS version FROM pg_extension ORDER BY extname) e", name)
        database_details.append({**database, "dump": str(dump_path.relative_to(staging)), "extensions": extensions})
    valid = {Path(database["dump"]).name for database in database_details} | {"globals.sql"}
    for stale in destination.iterdir():
        if stale.name not in valid and stale.is_file():
            stale.unlink()
    return {"paths": file_details, "databases": database_details, "globals": str(globals_path.relative_to(staging)), "server": server, "tablespaces": tablespaces, "simultaneousClusterSnapshot": False}



def _victoria_api(url):
    try:
        with urlopen(url, timeout=30) as response:
            result = json.load(response)
        if result.get("status") != "ok":
            raise CaptureError("VictoriaMetrics snapshot API did not succeed")
        return result
    except (OSError, URLError, ValueError) as error:
        raise CaptureError(f"VictoriaMetrics snapshot API failed: {error}") from error


def _victoria(entry, staging, timeout_seconds):
    source = Path(entry["storagePath"])
    if not source.is_absolute() or not source.is_dir():
        raise CaptureError(f"VictoriaMetrics storage path is missing: {source}")
    url = entry["url"].rstrip("/")
    snapshot = _victoria_api(url + "/snapshot/create").get("snapshot")
    if not snapshot or "/" in snapshot or snapshot in (".", ".."):
        raise CaptureError("VictoriaMetrics returned an invalid snapshot name")
    destination = staging / "databases" / entry["name"]
    try:
        _run(["vmbackup", "-storageDataPath=" + str(source.resolve()), "-snapshotName=" + snapshot, "-dst=fs://" + str(destination)])
    finally:
        # No delete_all: snapshots created by an operator or another job remain.
        _victoria_api(url + "/snapshot/delete?" + urlencode({"snapshot": snapshot}))
    return {"paths": _files(entry, staging, timeout_seconds), "storagePath": str(source), "resolvedSource": str(source.resolve()), "backup": str(destination.relative_to(staging)), "captureMethod": "vmbackup", "snapshot": snapshot}

def _archive_paths(archive):
    paths = {archive["path"]} if archive.get("path") else set()
    for dependency in archive.get("inputs", {}).values():
        paths.update(_archive_paths(dependency))
    return paths


def _nix(entry, staging, timeout_seconds):
    flake = Path(entry["flakePath"])
    if not flake.is_absolute() or not (flake / "flake.nix").is_file() or not (flake / "flake.lock").is_file():
        raise CaptureError(f"Recovery configuration and flake.lock are required: {flake}")
    recovery = staging / "recovery" / entry["name"]
    cache = recovery / "input-cache"
    recovery.mkdir(parents=True, exist_ok=True)
    store_dir = _run(["nix", "eval", "--raw", "--expr", "builtins.storeDir"]).decode().strip()
    cache_uri = cache.as_uri() + "?" + urlencode({"store": store_dir})
    output = _run(["nix", "flake", "archive", "--json", "--no-write-lock-file", "--to", cache_uri, str(flake)])
    try:
        archive = json.loads(output)
    except ValueError as error:
        raise CaptureError("Invalid Nix flake archive output") from error
    source_paths = _archive_paths(archive)
    # Selected sources may reference other sources. Preserve their closure, not
    # the entire machine's regenerable /nix/store.
    closure = json.loads(_run(["nix", "path-info", "--recursive", "--json", *sorted(source_paths)]))
    closure_paths = set(closure) if isinstance(closure, dict) else {path["path"] for path in closure}
    live_narinfos = {Path(path).name.split("-", 1)[0] + ".narinfo" for path in closure_paths}
    live_nars = set()
    for narinfo in cache.glob("*.narinfo"):
        if narinfo.name not in live_narinfos:
            narinfo.unlink()
            continue
        for line in narinfo.read_text().splitlines():
            if line.startswith("URL: "):
                live_nars.add(line[5:])
    if (cache / "nar").exists():
        for nar in (cache / "nar").iterdir():
            if str(nar.relative_to(cache)) not in live_nars and nar.is_file():
                nar.unlink()
    (recovery / "store-dir").write_text(store_dir + "\n")
    (recovery / "archive.json").write_text(json.dumps(archive, indent=2) + "\n")
    (recovery / "closure.json").write_text(json.dumps(sorted(closure_paths), indent=2) + "\n")
    sources = [flake, *_paths(entry)]
    paths = [_copy(source, staging, entry.get("excludes", [])) for source in sources]
    system = Path("/run/current-system")
    system_version = str(system.resolve()) if system.exists() else None
    version = _run(["nix", "--version"]).decode().strip()
    return {"paths": paths, "archive": str((recovery / "archive.json").relative_to(staging)), "inputCache": str(cache.relative_to(staging)), "sourcePaths": sorted(closure_paths), "nixVersion": version, "storeDir": store_dir, "systemClosure": system_version}

def _terminated(signum, frame):
    raise CaptureError(f"Capture interrupted by signal {signum}")


def prepare(scope_config: dict, staging: Path, *, timeout_seconds: int = 60) -> list[Path]:
    """Materialize a complete capture, or fail without permitting upload."""
    staging = Path(staging)
    staging.mkdir(mode=0o700, parents=True, exist_ok=True)
    staging.chmod(0o700)
    manifest_path = staging / "capture-manifest.json"
    manifest_path.unlink(missing_ok=True)
    manifest = {"version": 1, "startedAt": time.time(), "captures": []}
    _trim_staging(scope_config, staging)
    previous_handlers = {signum: signal.getsignal(signum) for signum in (signal.SIGTERM, signal.SIGINT)}
    for signum in previous_handlers:
        signal.signal(signum, _terminated)
    try:
        for entry in scope_config.get("captures", []):
            if entry["kind"] == "files":
                details = {"paths": _files(entry, staging, timeout_seconds)}
            elif entry["kind"] == "sqlite":
                details = _sqlite(entry, staging, timeout_seconds)
            elif entry["kind"] == "postgres":
                details = _postgres(entry, staging, timeout_seconds)
            elif entry["kind"] == "nix":
                details = _nix(entry, staging, timeout_seconds)
            elif entry["kind"] == "victoria":
                details = _victoria(entry, staging, timeout_seconds)
            else:
                raise CaptureError(f"Unknown capture kind: {entry['kind']}")
            record = {"name": entry["name"], "kind": entry["kind"], **details}
            if entry.get("writerCoverageNote"):
                record["writerCoverageNote"] = entry["writerCoverageNote"]
            manifest["captures"].append(record)
        manifest["completedAt"] = time.time()
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
        manifest_path.chmod(0o600)
        return [path for path in (staging / "tree", staging / "databases", staging / "recovery", manifest_path) if path.exists()]
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        raise CaptureError(f"Local capture failed: {error}") from error
    finally:
        for signum, handler in previous_handlers.items():
            signal.signal(signum, handler)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--resume-watchdog":
        _resume_watchdog(Path(sys.argv[2]))
    elif len(sys.argv) == 3 and sys.argv[1] == "--service-watchdog":
        _service_watchdog(Path(sys.argv[2]))
    else:
        raise SystemExit("Use capture.prepare, --resume-watchdog PLAN, or --service-watchdog PLAN")
