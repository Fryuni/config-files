#!/usr/bin/env python3
"""Exercise the machine-backup CLI against disposable real restic repositories."""

import json
import importlib.util
from datetime import datetime, timedelta, timezone
import fcntl
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import select
import shlex
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
import unittest


RUNNER = Path(__file__).resolve().parents[1] / "common/backups/runner.py"


class BackupRunnerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="backup-runner-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.password = self.root / "password"
        self.password.write_text("test-only-password\n")
        self.password.chmod(0o600)
        self.source = self.root / "home"
        self.source.mkdir()
        self.repo = self.root / "repository"
        self.config = {
            "host": "loem",
            "repository": str(self.repo),
            "passwordFile": str(self.password),
            "stateDirectory": str(self.root / "loem-state"),
            "scopes": {"home": {"paths": [str(self.source)], "excludes": []}},
        }

    def cli(self, *arguments, config=None, expected=0, env=None):
        path = self.root / "config.json"
        path.write_text(json.dumps(config or self.config))
        result = subprocess.run(
            [sys.executable, str(RUNNER), "--config", str(path), *arguments],
            text=True, capture_output=True, env=env,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def restic(self, *arguments):
        result = subprocess.run(
            ["restic", "--repo", str(self.repo), "--password-file", str(self.password),
             *arguments], capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        return result.stdout

    def snapshots(self):
        return json.loads(self.restic("snapshots", "--json")) or []

    def historical_point(self, host, scope, days, complete=True):
        time = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d %H:%M:%S")
        arguments = ["backup", "--json", "--host", host, "--time", time,
                     "--tag", "machine-backup", "--tag", scope]
        if complete:
            arguments.extend(["--tag", "complete"])
        output = self.restic(*arguments, str(self.source))
        return next(json.loads(line)["snapshot_id"] for line in output.splitlines()
                    if json.loads(line).get("message_type") == "summary")

    def failing_restic_boundary(self, command, exit_code, stderr):
        binary = self.root / "boundary-bin"
        binary.mkdir(exist_ok=True)
        wrapper = binary / "restic"
        wrapper.write_text("""#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys
with pathlib.Path(os.environ['RESTIC_FIXTURE_CALLS']).open('a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\\n')
if os.environ['RESTIC_FIXTURE_COMMAND'] in sys.argv[1:]:
    print(os.environ['RESTIC_FIXTURE_STDERR'], file=sys.stderr)
    sys.exit(int(os.environ['RESTIC_FIXTURE_EXIT']))
sys.exit(subprocess.run([os.environ['RESTIC_FIXTURE_REAL'], *sys.argv[1:]]).returncode)
""")
        wrapper.chmod(0o755)
        self.boundary_log = self.root / "restic-calls.jsonl"
        # Fixture variables do not use RESTIC_*: those are deliberately stripped by the runner.
        contents = wrapper.read_text().replace("RESTIC_FIXTURE_", "BACKUP_FIXTURE_").replace(
            "#!/usr/bin/env python3", "#!" + sys.executable)
        wrapper.write_text(contents)
        return dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"],
                    BACKUP_FIXTURE_REAL=shutil.which("restic"), BACKUP_FIXTURE_COMMAND=command,
                    BACKUP_FIXTURE_EXIT=str(exit_code), BACKUP_FIXTURE_STDERR=stderr,
                    BACKUP_FIXTURE_CALLS=str(self.boundary_log))

    def test_home_backup_creates_a_complete_recoverable_restore_point(self):
        (self.source / "project.txt").write_text("uncommitted work\n")
        self.cli("backup", "--scope", "home")
        snapshots = self.snapshots()
        self.assertEqual(len(snapshots), 1)
        self.assertEqual(snapshots[0]["hostname"], "loem")
        self.assertEqual(set(snapshots[0]["tags"]), {"machine-backup", "home", "complete"})
        self.assertEqual(self.restic("dump", snapshots[0]["id"],
                                    str(self.source / "project.txt")), b"uncommitted work\n")

    def test_backup_reports_progress_before_upload_finishes(self):
        binary = self.root / "bin"
        binary.mkdir()
        release = self.root / "release-upload"
        restic = binary / "restic"
        restic.write_text("#!" + sys.executable + "\n" + """
import json, os, pathlib, sys, time
if 'backup' in sys.argv:
    assert os.environ.get('RESTIC_PROGRESS_FPS') == '0.2'
    print('fixture: waiting for remote data', file=sys.stderr, flush=True)
    print(json.dumps({'message_type': 'status', 'percent_done': 0.5,
                      'files_done': 2, 'total_files': 4,
                      'bytes_done': 1024, 'total_bytes': 2048}), flush=True)
    deadline = time.monotonic() + 10
    while not pathlib.Path(os.environ['BACKUP_RELEASE']).exists():
        if time.monotonic() > deadline:
            sys.exit(1)
        time.sleep(0.01)
    print(json.dumps({'message_type': 'summary', 'snapshot_id': 'fixture-snapshot'}))
""")
        restic.chmod(0o755)
        # Speed up only the 15-second heartbeat interval, keeping the real CLI,
        # subprocess pipes and blocking upload unchanged.
        (binary / "sitecustomize.py").write_text("""
import threading
original_wait = threading.Event.wait
def wait(self, timeout=None):
    return original_wait(self, 0.05 if timeout == 15 else timeout)
threading.Event.wait = wait
""")
        config = self.root / "config.json"
        config.write_text(json.dumps(self.config))
        environment = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"],
                           BACKUP_RELEASE=str(release), PYTHONPATH=str(binary),
                           PYTHONDONTWRITEBYTECODE="1")
        with subprocess.Popen(
            [sys.executable, str(RUNNER), "--config", str(config), "backup", "--scope", "home"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=environment,
        ) as process:
            output = b""
            try:
                deadline = time.monotonic() + 3
                while (b"50.0%" not in output or output.count(b"still running") < 2) and time.monotonic() < deadline:
                    if select.select([process.stderr], [], [], 0.1)[0]:
                        chunk = os.read(process.stderr.fileno(), 65536)
                        if not chunk:
                            break
                        output += chunk
                self.assertIn(b"50.0%", output, "No live upload progress: " + output.decode())
                self.assertIn(b"fixture: waiting for remote data", output)
                self.assertGreaterEqual(output.count(b"still running"), 2, output.decode())
                self.assertTrue(all(line.count(b"still running") == 1
                                    for line in output.splitlines() if b"still running" in line))
                self.assertIsNone(process.poll(), "Progress arrived only after the backup exited")
            finally:
                release.touch()
                stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, (output + stderr).decode())
            self.assertTrue(json.loads(stdout)["complete"])

    def test_backup_reports_named_capture_stages(self):
        (self.source / "state").write_text("capture this")
        self.config["scopes"]["home"] = {"captures": [
            {"name": "fixture-app", "kind": "files", "paths": [str(self.source)]},
        ]}
        result = self.cli("backup", "--scope", "home")
        messages = ["checking backup repository", "preparing local captures",
                    "Preparing capture fixture-app (files)", "Capture fixture-app prepared",
                    "scanning and uploading backup", "marking snapshot", "backup complete"]
        positions = [result.stderr.index(message) for message in messages]
        self.assertEqual(positions, sorted(positions))
        self.assertTrue(json.loads(result.stdout)["complete"])

    def test_service_files_are_backed_up_without_a_staging_copy(self):
        payload = self.source / "service-data.bin"
        payload.write_bytes(os.urandom(1024 * 1024))
        self.config["scopes"] = {"services": {"captures": [
            {"name": "fixture-service", "kind": "files", "paths": [str(self.source)]},
        ]}}
        self.cli("backup", "--scope", "services")
        staging = Path(self.config["stateDirectory"]) / "staging/services"
        self.assertFalse((staging / "tree").exists(), "Service payload was duplicated into staging")
        self.assertEqual(self.restic("dump", self.snapshots()[0]["id"], str(payload)), payload.read_bytes())

    def test_direct_selection_is_literal_and_exclusions_stay_with_their_service(self):
        service = self.source / "service [one]*\nstate"
        other = self.source / "other-service"
        for root in [service, other]:
            (root / "logs").mkdir(parents=True)
            (root / "logs/main.log").write_text("diagnostic")
            (root / "logs/v1-responses-request.log").write_text("valuable exchange")
            (root / "nested/cache").mkdir(parents=True)
            (root / "nested/cache/temp").write_text("regenerable")
            (root / "nested/.direnv").mkdir()
            (root / "nested/.direnv/temp").write_text("environment")
        self.config["scopes"] = {"services": {"captures": [
            {"name": "one", "kind": "files", "paths": [str(service)], "excludes": ["/logs/main.log", "cache"]},
            {"name": "other", "kind": "files", "paths": [str(other)]},
        ]}}
        stale = Path(self.config["stateDirectory"]) / "staging/services/tree/obsolete"
        stale.mkdir(parents=True)
        (stale / "payload").write_text("old duplicate")
        self.cli("backup", "--scope", "services")
        target = self.root / "restored-selection"
        self.cli("restore-test", "--host", "loem", "--scope", "services", "--target", str(target))
        selected = target / service.relative_to("/")
        retained = target / other.relative_to("/")
        self.assertFalse((selected / "logs/main.log").exists())
        self.assertFalse((selected / "nested/cache").exists())
        self.assertEqual((selected / "logs/v1-responses-request.log").read_text(), "valuable exchange")
        self.assertTrue((retained / "logs/main.log").exists())
        self.assertTrue((retained / "nested/cache/temp").exists())
        self.assertFalse((retained / "nested/.direnv").exists())
        self.assertFalse(stale.parent.exists())

    def test_direct_private_state_includes_the_target_and_preserves_internal_links(self):
        private = self.root / "private/app"
        private.mkdir(parents=True, mode=0o750)
        (private / "identity.key").write_text("service identity")
        (private / "identity.key").chmod(0o600)
        (private / "alias").symlink_to("identity.key")
        logical = self.source / "app"
        logical.symlink_to(private, target_is_directory=True)
        self.config["scopes"] = {"services": {"captures": [
            {"name": "private-app", "kind": "files", "paths": [str(logical)]},
        ]}}
        self.cli("backup", "--scope", "services")
        target = self.root / "private-restore"
        self.cli("restore-test", "--host", "loem", "--scope", "services", "--target", str(target))
        restored = target / private.relative_to("/")
        self.assertEqual((restored / "identity.key").read_text(), "service identity")
        self.assertEqual((restored / "alias").readlink(), Path("identity.key"))
        self.assertEqual((restored / "identity.key").stat().st_mode & 0o777, 0o600)

    def test_stalled_direct_upload_is_aborted_and_managed_services_recover(self):
        spec = importlib.util.spec_from_file_location("capture_fixture", Path(__file__).with_name("backups-capture.py"))
        fixture = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(fixture)
        services = fixture.CaptureTests()
        services.setUp()
        self.addCleanup(services.doCleanups)
        services.fake_services({"app.service": True})
        real_restic = shutil.which("restic")
        wrapper = services.root / "bin/restic"
        wrapper.write_text("#!" + sys.executable + "\n" + """
import json, os, pathlib, sys, time
if 'backup' in sys.argv:
    assert not json.loads(pathlib.Path(os.environ['CAPTURE_TEST_UNITS']).read_text())['app.service']
    time.sleep(30)
else:
    os.execv(REAL, [REAL, *sys.argv[1:]])
""".replace("REAL", repr(real_restic)))
        wrapper.chmod(0o755)
        self.config["timeoutSeconds"] = 1
        self.config["scopes"] = {"services": {"captures": [
            {"name": "app", "kind": "files", "paths": [str(self.source)], "units": [{"name": "app.service"}]},
        ]}}
        result = self.cli("backup", "--scope", "services", expected=1)
        self.assertIn("interruption limit expired", result.stderr)
        self.assertTrue(json.loads(services.service_state.read_text())["app.service"])
        self.assertFalse(self.snapshots())

    def test_native_victoria_links_are_recoverable_after_snapshot_cleanup(self):
        storage = self.source / "metrics"
        snapshots = {"unrelated"}
        root = storage / "snapshots/backup"
        chunks = storage / "immutable/backup"
        class API(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/snapshot/create":
                    root.mkdir(parents=True)
                    chunks.mkdir(parents=True)
                    (chunks / "metric.chunk").write_bytes(b"recoverable native metrics")
                    (root / "data").symlink_to(chunks, target_is_directory=True)
                    snapshots.add("backup")
                    result = {"status": "ok", "snapshot": "backup"}
                elif self.path == "/snapshot/delete?snapshot=backup":
                    snapshots.remove("backup")
                    shutil.rmtree(root)
                    shutil.rmtree(chunks)
                    result = {"status": "ok"}
                else:
                    self.send_error(404)
                    return
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())
            def log_message(self, *args):
                pass
        server = ThreadingHTTPServer(("127.0.0.1", 0), API)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        self.config["scopes"] = {"services": {"captures": [
            {"name": "victoria", "kind": "victoria", "storagePath": str(storage),
             "url": "http://127.0.0.1:" + str(server.server_port)},
        ]}}
        storage.mkdir()
        self.cli("backup", "--scope", "services")
        self.assertEqual(snapshots, {"unrelated"})
        self.assertFalse(chunks.exists())
        staging = Path(self.config["stateDirectory"]) / "staging/services"
        self.assertFalse((staging / "databases/victoria").exists())
        target = self.root / "restored-metrics"
        self.cli("restore-test", "--host", "loem", "--scope", "services", "--target", str(target))
        reconstructed = target / staging.relative_to("/") / "native-snapshots/victoria/data/metric.chunk"
        self.assertEqual(reconstructed.read_bytes(), b"recoverable native metrics")
        environment = self.failing_restic_boundary("backup", 1, "connection reset")
        self.cli("backup", "--scope", "services", expected=75, env=environment)
        self.assertEqual(snapshots, {"unrelated"})
        self.assertFalse(root.exists())

    def test_backup_restore_preserves_acl_and_extended_attributes(self):
        source = self.source / "metadata.txt"
        source.write_text("retain file metadata")
        source.chmod(0o640)
        acl = subprocess.run(["setfacl", "-m", "u:65534:r--", str(source)], capture_output=True)
        if acl.returncode and b"Operation not supported" in acl.stderr:
            self.skipTest("Fixture filesystem does not support POSIX ACLs")
        self.assertEqual(acl.returncode, 0, acl.stderr.decode())
        os.setxattr(source, "user.backup-test", b"valuable metadata")
        self.cli("backup", "--scope", "home")
        target = self.root / "metadata-restore"
        self.cli("restore-test", "--host", "loem", "--scope", "home", "--target", str(target))
        restored = target / source.relative_to("/")
        self.assertEqual(restored.stat().st_mode, source.stat().st_mode)
        for attribute in ["system.posix_acl_access", "user.backup-test"]:
            self.assertEqual(os.getxattr(restored, attribute), os.getxattr(source, attribute))

    def test_shared_repository_keeps_each_hosts_version_and_deduplicates_content(self):
        common = os.urandom(1024 * 1024)
        (self.source / "common.bin").write_bytes(common)
        (self.source / "project.txt").write_text("loem work\n")
        self.cli("backup", "--scope", "home")
        first_size = json.loads(self.restic("stats", "--mode", "raw-data", "--json"))["total_size"]
        (self.source / "project.txt").write_text("note work\n")
        notebook = dict(self.config, host="note", stateDirectory=str(self.root / "note-state"))
        self.cli("backup", "--scope", "home", config=notebook)
        snapshots = {snapshot["hostname"]: snapshot for snapshot in self.snapshots()}
        for host in ["loem", "note"]:
            self.assertEqual(self.restic("dump", snapshots[host]["id"],
                                        str(self.source / "project.txt")), (host + " work\n").encode())
        final_size = json.loads(self.restic("stats", "--mode", "raw-data", "--json"))["total_size"]
        self.assertLess(final_size - first_size, 100 * 1024)

    def test_nested_direnv_is_excluded_but_all_request_exchange_families_survive(self):
        nested = self.source / "project" / "deeper" / ".direnv"
        nested.mkdir(parents=True)
        (nested / "environment").write_text("rebuild me")
        logs = self.source / "logs"
        logs.mkdir()
        for name in ["main.log", "main-2026.log", "v1-messages-1.log",
                     "v1-responses-1.log", "error-unfamiliar-api-1.log"]:
            (logs / name).write_text(name)
        self.config["scopes"]["home"]["excludes"] = [str(logs / "main.log"), str(logs / "main-*.log")]
        self.cli("backup", "--scope", "home")
        point = self.snapshots()[0]["id"]
        restored = self.root / "restore"
        self.restic("restore", point, "--target", str(restored))
        tree = restored / str(self.source).lstrip("/")
        self.assertFalse((tree / "project/deeper/.direnv").exists())
        self.assertFalse((tree / "logs/main.log").exists())
        self.assertFalse((tree / "logs/main-2026.log").exists())
        for name in ["v1-messages-1.log", "v1-responses-1.log", "error-unfamiliar-api-1.log"]:
            self.assertEqual((tree / "logs" / name).read_text(), name)

    @unittest.skipIf(os.geteuid() == 0, "chmod unreadable fixture requires an unprivileged test user")
    def test_partial_backup_does_not_replace_last_complete_restore_point(self):
        readable = self.source / "good.txt"
        readable.write_text("restorable")
        self.cli("backup", "--scope", "home")
        before = json.loads(self.cli("status").stdout)["lastComplete"]["home"]
        unreadable = self.source / "private.txt"
        unreadable.write_text("not captured")
        unreadable.chmod(0)
        self.addCleanup(unreadable.chmod, 0o600)
        self.cli("backup", "--scope", "home", expected=1)
        after = json.loads(self.cli("status").stdout)["lastComplete"]["home"]
        self.assertEqual(after, before)
        snapshots = self.snapshots()
        self.assertEqual(len(snapshots), 2)
        complete = [point for point in snapshots if "complete" in point.get("tags", [])]
        self.assertEqual(len(complete), 1)
        self.assertEqual(self.restic("dump", complete[0]["id"], str(readable)), b"restorable")

    def test_failed_complete_tag_leaves_candidate_unhealthy_and_preserves_prior_complete(self):
        (self.source / "file").write_text("first complete copy")
        self.cli("backup", "--scope", "home")
        previous = json.loads(self.cli("status").stdout)["lastComplete"]["home"]
        (self.source / "file").write_text("uploaded but not confirmed")
        boundary = self.failing_restic_boundary("tag", 12, "wrong password")
        self.cli("backup", "--scope", "home", expected=1, env=boundary)
        self.assertEqual(json.loads(self.cli("status").stdout)["lastComplete"]["home"], previous)
        self.assertEqual(len([point for point in self.snapshots() if "complete" in point.get("tags", [])]), 1)

    def test_authentication_failure_never_attempts_repository_initialization(self):
        (self.source / "file").write_text("valuable")
        boundary = self.failing_restic_boundary("cat", 12, "wrong password")
        self.cli("backup", "--scope", "home", expected=1, env=boundary)
        calls = [json.loads(line) for line in self.boundary_log.read_text().splitlines()]
        self.assertFalse(any("init" in command for command in calls))
        self.assertFalse(self.repo.exists())

    def test_maintenance_retains_offline_machine_and_scope_history_independently(self):
        (self.source / "state").write_text("same contents")
        self.restic("init")
        self.historical_point("loem", "home", 902)
        obsolete = self.historical_point("loem", "home", 901)
        self.historical_point("loem", "home", 0)
        offline_home = self.historical_point("note", "home", 901)
        offline_services = self.historical_point("loem", "services", 901)
        candidate = self.historical_point("loem", "services", 900, complete=False)
        self.cli("maintain")
        ids = {point["id"] for point in self.snapshots()}
        self.assertNotIn(obsolete, ids)
        self.assertNotIn(candidate, ids)
        self.assertIn(offline_home, ids)
        self.assertIn(offline_services, ids)
        status = json.loads(self.cli("status").stdout)
        self.assertEqual(status["nextCheckQuarter"], 2)
        self.assertTrue(status["lastIntegrityCheck"])

    def test_failed_integrity_check_preserves_history_and_check_rotation(self):
        (self.source / "data").write_text("preserve this")
        self.cli("backup", "--scope", "home")
        before = self.snapshots()
        boundary = self.failing_restic_boundary("check", 1, "Fatal: repository contains errors")
        self.cli("maintain", expected=1, env=boundary)
        self.assertEqual(self.snapshots(), before)
        status = json.loads(self.cli("status").stdout)
        self.assertEqual(status.get("nextCheckQuarter", 1), 1)
        self.assertFalse(status.get("lastIntegrityCheck"))

    def test_mutual_monitor_ignores_partial_points_and_notifies_only_transitions(self):
        delivered = []

        class Gotify(BaseHTTPRequestHandler):
            def do_POST(self):
                self.server.testcase.assertEqual(self.headers["X-Gotify-Key"], "test-only-token")
                delivered.append(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))
                self.send_response(200)
                self.end_headers()

            def log_message(self, *arguments):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Gotify)
        server.testcase = self
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        token = self.root / "gotify-token"
        token.write_text("test-only-token")
        self.config["gotify"] = {"url": "http://127.0.0.1:" + str(server.server_port), "tokenFile": str(token)}
        self.config["peerHost"] = "note"
        (self.source / "state").write_text("coherent data")
        self.restic("init")
        self.historical_point("loem", "home", 13 / 24)
        self.historical_point("loem", "services", 3 / 24)
        self.historical_point("note", "home", 1 / 24)
        self.historical_point("note", "services", 3 / 24)
        self.historical_point("note", "services", 0, complete=False)
        self.cli("monitor")
        self.assertEqual(len(delivered), 3)
        self.assertTrue(any("note services" in message["message"] for message in delivered))
        self.cli("monitor")
        self.assertEqual(len(delivered), 3)
        for host, scope in [("loem", "home"), ("loem", "services"), ("note", "services")]:
            self.historical_point(host, scope, 0)
        self.cli("monitor")
        self.assertEqual(len(delivered), 6)
        self.assertTrue(all(message["message"].startswith("Recovered:") for message in delivered[3:]))
        self.assertEqual(json.loads(self.cli("status").stdout)["notifications"], [])

    def test_monitor_credential_recovery_clears_failure_and_critical_health(self):
        self.restic("init")
        boundary = self.failing_restic_boundary("snapshots", 12, "Fatal: authentication failed")
        self.cli("monitor", expected=1, env=boundary)
        failed = json.loads(self.cli("status").stdout)
        self.assertTrue(any(entry["level"] == "critical" for entry in failed["health"].values()))
        self.cli("monitor")
        recovered = json.loads(self.cli("status").stdout)
        self.assertFalse(any(entry["level"] == "critical" for entry in recovered["health"].values()))
        self.assertEqual(recovered["lastFailure"], {})
        repository_recoveries = [message for message in recovered["notifications"]
                                 if message["message"] == "Recovered: Repository access succeeded"]
        self.assertEqual(len(repository_recoveries), 1)

    def test_restore_rehearsal_recovers_home_and_consistent_service_replacements_in_isolation(self):
        app = self.source / ".app"
        app.mkdir()
        with sqlite3.connect(app / "history.db") as database:
            database.execute("CREATE TABLE work (value TEXT)")
            database.execute("INSERT INTO work VALUES ('valuable service history')")
        (app / "generated.key").write_text("application identity")
        (app / "main.log").write_text("discard diagnostics")
        (app / "v1-responses-1.log").write_text("valuable corpus")
        (self.source / "notes.txt").write_text("home work")
        self.config["scopes"]["home"].update({
            "excludes": [str(app / "main.log")],
            "captures": [{"name": "app", "kind": "sqlite", "paths": [str(app)]}],
        })
        self.cli("backup", "--scope", "home")
        target = self.root / "isolated-restore"
        result = self.cli("restore-test", "--host", "loem", "--scope", "home", "--target", str(target))
        self.assertGreater(json.loads(result.stdout)["verifiedSqliteDatabases"], 0)
        direct = target / str(app).lstrip("/")
        self.assertTrue(direct.is_dir())
        self.assertFalse((direct / "history.db").exists())
        copied = target / str(Path(self.config["stateDirectory"]) / "staging/home/tree").lstrip("/") / str(app).lstrip("/")
        with sqlite3.connect(copied / "history.db") as database:
            self.assertEqual(database.execute("SELECT value FROM work").fetchall(), [("valuable service history",)])
        self.assertEqual((direct / "generated.key").read_text(), "application identity")
        self.assertEqual((direct / "v1-responses-1.log").read_text(), "valuable corpus")
        self.assertFalse((direct / "main.log").exists())
        self.assertEqual((target / str(self.source / "notes.txt").lstrip("/")).read_text(), "home work")
        self.cli("restore-test", "--host", "loem", "--scope", "home", "--target", str(target), expected=1)

    def test_verified_restore_recovers_once_and_a_later_failure_alerts_again(self):
        with sqlite3.connect(self.source / "history.db") as database:
            database.execute("CREATE TABLE work (value TEXT)")
            database.execute("INSERT INTO work VALUES ('restore this history')")
        self.cli("backup", "--scope", "home")
        boundary = self.failing_restic_boundary("restore", 12, "Fatal: authentication failed")
        self.cli("restore-test", "--host", "loem", "--scope", "home",
                 "--target", str(self.root / "failed-restore"), expected=1, env=boundary)
        failed = json.loads(self.cli("status").stdout)
        self.assertEqual(failed["health"]["restore-test:home"]["level"], "critical")
        self.assertIn("restore-test:home", failed["lastFailure"])

        result = self.cli("restore-test", "--host", "loem", "--scope", "home",
                          "--target", str(self.root / "verified-restore"))
        self.assertEqual(json.loads(result.stdout)["verifiedSqliteDatabases"], 1)
        recovered = json.loads(self.cli("status").stdout)
        self.assertEqual(recovered["health"]["restore-test:home"]["level"], "ok")
        self.assertNotIn("restore-test:home", recovered["lastFailure"])
        recovery_message = "Recovered: home restore rehearsal succeeded"
        self.assertEqual(sum(message["message"] == recovery_message
                             for message in recovered["notifications"]), 1)

        self.cli("restore-test", "--host", "loem", "--scope", "home",
                 "--target", str(self.root / "another-verified-restore"))
        repeated = json.loads(self.cli("status").stdout)
        self.assertEqual(repeated["notifications"], recovered["notifications"])
        self.cli("restore-test", "--host", "loem", "--scope", "home",
                 "--target", str(self.root / "later-failed-restore"), expected=1, env=boundary)
        failed_again = json.loads(self.cli("status").stdout)
        self.assertEqual(failed_again["health"]["restore-test:home"]["level"], "critical")
        self.assertEqual(len(failed_again["notifications"]), len(recovered["notifications"]) + 1)
        self.assertEqual(failed_again["notifications"][-1]["priority"], 8)

    def test_inventory_flags_unclassified_service_state_and_container_mounts(self):
        known, unknown, cache, volume = [self.root / name for name in ["known", "unknown", "cache", "new-volume"]]
        for path in [known, unknown, cache, volume]:
            path.mkdir()
        binaries = self.root / "bin"
        binaries.mkdir()
        systemctl = binaries / "systemctl"
        systemctl.write_text("""#!/usr/bin/env python3
import os, sys
if 'list-units' in sys.argv:
    print('known.service loaded active running known')
    print('unknown.service loaded active running unknown')
    print('cache.service loaded active running cache')
else:
    print(os.environ['INVENTORY_' + sys.argv[-1].split('.')[0].upper()])
""")
        docker = binaries / "docker"
        docker.write_text("""#!/usr/bin/env python3
import json, os, sys
if sys.argv[1] == 'ps':
    print('container-fixture')
else:
    print(json.dumps([{'Type':'volume','Source':os.environ['INVENTORY_VOLUME'],'Destination':'/data'}]))
""")
        systemctl.chmod(0o755)
        docker.chmod(0o755)
        for script in [systemctl, docker]:
            script.write_text(script.read_text().replace("#!/usr/bin/env python3", "#!" + sys.executable))
        environment = dict(os.environ, PATH=str(binaries) + os.pathsep + os.environ["PATH"],
                           INVENTORY_KNOWN=str(known), INVENTORY_UNKNOWN=str(unknown),
                           INVENTORY_CACHE=str(cache), INVENTORY_VOLUME=str(volume))
        cluster = known / "17"
        cluster.mkdir()
        self.config["inventory"] = {"enabled": True, "coveredPaths": [str(cluster)],
                                     "scaffolds": [{"path": str(known), "reason": "cluster parent"}],
                                     "classifiedRegenerable": [{"path": str(cache), "reason": "regenerable fixture"}]}
        (self.source / "data").write_text("backed up")
        self.cli("backup", "--scope", "home")
        self.historical_point("loem", "services", 0)
        self.cli("monitor", env=environment)
        status = json.loads(self.cli("status").stdout)
        uncovered = {entry["path"] for entry in status["inventory"]["uncoveredPaths"]}
        self.assertEqual(uncovered, {str(unknown), str(volume)})
        self.assertEqual(status["health"]["inventory"]["level"], "warning")
        new_cluster = known / "18"
        new_cluster.mkdir()
        self.cli("inventory", env=environment)
        uncovered = {entry["path"] for entry in json.loads(self.cli("status").stdout)["inventory"]["uncoveredPaths"]}
        self.assertEqual(uncovered, {str(unknown), str(volume), str(new_cluster)})

    def test_sftp_uses_port_22_with_dedicated_identity_and_pinned_trust(self):
        identity = self.root / "dedicated-key"
        identity.touch()
        hosts = self.root / "pinned-hosts"
        hosts.touch()
        self.config["repository"] = "sftp://backup@storagebox.example:22/restic"
        self.config["ssh"] = {"host": "storagebox.example", "user": "backup", "port": 22,
                               "commandPort": 23, "identityFile": str(identity),
                               "knownHostsFile": str(hosts)}
        environment = self.failing_restic_boundary("cat", 0, "")
        self.cli("restic", "--", "cat", "config", env=environment)
        calls = [json.loads(line) for line in self.boundary_log.read_text().splitlines()]
        command = shlex.split(next(argument.removeprefix("sftp.command=")
                                  for argument in calls[-1] if argument.startswith("sftp.command=")))
        self.assertEqual(command[command.index("-p") + 1], "22")
        self.assertEqual(command[command.index("-i") + 1], str(identity))
        self.assertIn("UserKnownHostsFile=" + str(hosts), command)
        self.assertIn("StrictHostKeyChecking=yes", command)
        self.assertEqual(command[-3:], ["backup@storagebox.example", "-s", "sftp"])

    def test_storage_pressure_uses_dedicated_ssh_and_queues_alerts_without_gotify_credentials(self):
        binary = self.root / "bin"
        binary.mkdir()
        ssh = binary / "ssh"
        ssh.write_text("""#!/usr/bin/env python3
import json, os, pathlib, sys
pathlib.Path(os.environ['SSH_FIXTURE_ARGUMENTS']).write_text(json.dumps({'args':sys.argv[1:], 'agent':os.environ.get('SSH_AUTH_SOCK')}))
percent = int(pathlib.Path(os.environ['SSH_FIXTURE_CAPACITY']).read_text().strip())
available = (100 - percent) * 1073741824 // 100
print('Filesystem 1024-blocks Used Available Capacity Mounted on')
# The reported ZFS filesystem total shrinks because hidden snapshots retain space.
# Its own percentage is deliberately unrelated to the fraction of purchased quota.
print('storagebox ' + str(available + 100000000) + ' 100000000 ' + str(available) + ' 20% /home')
""")
        ssh.chmod(0o755)
        ssh.write_text(ssh.read_text().replace("#!/usr/bin/env python3", "#!" + sys.executable))
        capacity = self.root / "capacity"
        observed = self.root / "ssh-arguments.json"
        environment = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"],
                           SSH_FIXTURE_ARGUMENTS=str(observed), SSH_FIXTURE_CAPACITY=str(capacity),
                           SSH_AUTH_SOCK="/tmp/untrusted-agent")
        self.config["ssh"] = {"host": "storagebox.example", "user": "backup", "port": 22,
                               "commandPort": 23,
                               "identityFile": str(self.root / "dedicated-key"),
                               "knownHostsFile": str(self.root / "pinned-hosts")}
        self.config["quotaBytes"] = 1099511627776
        self.config["gotify"] = {"url": "http://127.0.0.1:1", "tokenFile": str(self.root / "missing-token")}
        (self.source / "work").write_text("restorable")
        self.cli("backup", "--scope", "home")
        self.historical_point("loem", "services", 0)
        for percent, level in [(70, "warning"), (85, "critical"), (69, "ok")]:
            capacity.write_text(str(percent))
            self.cli("monitor", env=environment)
            status = json.loads(self.cli("status").stdout)
            self.assertEqual(status["capacity"]["percent"], percent)
            self.assertEqual(status["health"]["capacity"]["level"], level)
        self.assertEqual(len(status["notifications"]), 3)
        self.assertEqual(status["notificationDelivery"]["level"], "unavailable")
        used = json.loads(observed.read_text())
        self.assertIsNone(used["agent"])
        self.assertIn("/dev/null", used["args"])
        self.assertIn(str(self.root / "dedicated-key"), used["args"])
        self.assertEqual(used["args"][used["args"].index("-p") + 1], "23")
        self.assertEqual(used["args"][-3:], ["df", "-kP", "."])
        for option in ["IdentityAgent=none", "IdentitiesOnly=yes", "StrictHostKeyChecking=yes",
                       "ControlMaster=no", "ControlPath=none", "PasswordAuthentication=no"]:
            self.assertIn(option, used["args"])

    def test_unavailable_capacity_warns_when_stale_and_finishes_other_monitor_checks(self):
        binary = self.root / "capacity-bin"
        binary.mkdir()
        ssh = binary / "ssh"
        ssh.write_text("#!" + sys.executable + "\n" + """
import os, time
mode = os.environ['CAPACITY_FIXTURE_MODE']
if mode == 'timeout':
    time.sleep(5)
elif mode == 'invalid':
    print('storagebox 100 used unknown 20% /home')
elif mode == 'failed-exit':
    raise SystemExit(1)
""")
        ssh.chmod(0o755)
        for name in ["systemctl", "docker"]:
            script = binary / name
            script.write_text("#!" + sys.executable + "\n")
            script.chmod(0o755)
        # Exercise a real subprocess TimeoutExpired through the public CLI without
        # waiting 45 seconds. Only the fixture SSH command's timeout is shortened.
        (binary / "sitecustomize.py").write_text("""
import subprocess
original_run = subprocess.run
def run(command, *args, **kwargs):
    if command[0] == 'ssh':
        kwargs['timeout'] = 0.1
    return original_run(command, *args, **kwargs)
subprocess.run = run
""")
        environment = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"],
                           PYTHONPATH=str(binary), PYTHONDONTWRITEBYTECODE="1")
        self.config["ssh"] = {"host": "storagebox.invalid", "user": "fixture", "port": 23,
                               "identityFile": str(self.root / "unused-key"),
                               "knownHostsFile": str(self.root / "unused-hosts")}
        self.config["inventory"] = {"enabled": True, "coveredPaths": [str(self.source)]}
        (self.source / "work").write_text("restorable")
        self.cli("backup", "--scope", "home")
        self.historical_point("loem", "services", 0)
        state_path = Path(self.config["stateDirectory"]) / "state.json"
        for mode in ["empty", "invalid", "timeout", "failed-exit"]:
            for hours in [1, 13, None]:
                with self.subTest(mode=mode, last_measurement_hours=hours):
                    before = json.loads(state_path.read_text())
                    measurement = {} if hours is None else {
                        "checkedAt": (datetime.now(timezone.utc) - timedelta(hours=hours)).isoformat(),
                        "percent": 10,
                    }
                    before["capacity"] = measurement
                    before.setdefault("health", {})["capacity"] = {"level": "ok"}
                    before["notifications"] = []
                    before["inventory"] = {"checkedAt": "2000-01-01T00:00:00+00:00"}
                    before["firstCompleteAt"] = (datetime.now(timezone.utc) - timedelta(days=31)).isoformat()
                    before.pop("growthReviewReminder", None)
                    state_path.write_text(json.dumps(before))
                    self.cli("monitor", env=dict(environment, CAPACITY_FIXTURE_MODE=mode),
                             expected=0 if mode == "failed-exit" else 75)
                    status = json.loads(self.cli("status").stdout)
                    stale = hours is None or hours > 12
                    self.assertEqual(status["health"]["capacity"]["level"], "warning" if stale else "ok")
                    self.assertEqual(status["capacity"], measurement)
                    self.assertNotEqual(status["inventory"]["checkedAt"], before["inventory"]["checkedAt"])
                    self.assertEqual(status["inventory"]["issues"], [])
                    self.assertIn("growthReviewReminder", status)
                    self.assertEqual(sum(message["message"] == "Storage Box capacity cannot be measured"
                                         for message in status["notifications"]), int(stale))
                    self.assertEqual(sum(message["title"] == "Review backup storage growth"
                                         for message in status["notifications"]), 1)

    def test_future_machine_without_a_peer_can_monitor_and_busy_backups_retry(self):
        self.config["host"] = "future"
        self.config["peerHost"] = None
        (self.source / "work").write_text("future machine work")
        self.cli("backup", "--scope", "home")
        self.historical_point("future", "services", 0)
        with (Path(self.config["stateDirectory"]) / "operation.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            self.cli("backup", "--scope", "home", expected=75)
            self.cli("monitor")
        self.assertEqual(len(self.snapshots()), 2)
        self.cli("maintain", expected=1)

    def test_admin_restic_uses_configured_repository_and_rejects_credential_overrides(self):
        (self.source / "work").write_text("restorable")
        self.cli("backup", "--scope", "home")
        points = json.loads(self.cli("restic", "--", "snapshots", "--json").stdout)
        self.assertEqual(points[0]["hostname"], "loem")
        self.cli("restic", "--", "--repo", str(self.root / "other"), "snapshots", expected=1)

    def test_missing_password_is_a_permanent_visible_failure_without_a_traceback(self):
        (self.source / "work").write_text("valuable")
        self.password.unlink()
        result = self.cli("backup", "--scope", "home", expected=1)
        self.assertNotIn("Traceback", result.stderr)
        state = json.loads(self.cli("status").stdout)
        self.assertEqual(state["health"]["backup:home"]["level"], "critical")

    def test_restore_rehearsal_refuses_targets_inside_native_service_storage(self):
        (self.source / "work").write_text("valuable")
        self.cli("backup", "--scope", "home")
        native = self.root / "victoria-storage"
        native.mkdir()
        self.config["scopes"]["services"] = {"captures": [
            {"name": "metrics", "kind": "victoria", "storagePath": str(native)},
        ]}
        target = native / "looks-empty-but-is-production"
        self.cli("restore-test", "--host", "loem", "--scope", "home", "--target", str(target), expected=1)
        self.assertFalse(target.exists())


if __name__ == "__main__":
    if not shutil.which("restic"):
        raise SystemExit("restic must be on PATH (run the backup-runner check via Nix)")
    unittest.main()
