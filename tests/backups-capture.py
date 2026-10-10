#!/usr/bin/env python3
"""Restore and failure tests at the public local-capture boundary."""
import importlib.util
import functools
from contextlib import closing
import json
import pathlib
import os
import shutil
import sqlite3
import subprocess
import threading
import time
import signal
import sys
import errno
import socket
from urllib.request import urlopen
from urllib.error import URLError
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse, urlencode
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("backup_capture", pathlib.Path(__file__).resolve().parents[1] / "common/backups/capture.py")
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def isolated_writers(test):
    """Use a private /proc so these signal tests can only reach fixture processes."""
    @functools.wraps(test)
    def run(self):
        if os.environ.get("CAPTURE_TEST_PRIVATE_PROC") != "1":
            result = subprocess.run(["unshare", "--user", "--map-root-user", "--pid", "--fork", "--mount-proc", sys.executable, str(pathlib.Path(__file__).resolve()), "CaptureTests." + test.__name__, "-v"], env={**os.environ, "CAPTURE_TEST_PRIVATE_PROC": "1"}, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if result.returncode:
                self.fail(result.stdout.decode() + result.stderr.decode())
            return
        test(self)
    return run


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.source = self.root / "source"
        self.source.mkdir()
        self.staging = self.root / "staging"

    def copied(self, source):
        return self.staging / "tree" / pathlib.Path(source).relative_to("/")

    def fake_services(self, states, *, stop_file=None, remove_on_stop=None, signal_on_stop=None, failed_restart=None):
        self.service_state = self.root / "units.json"
        self.service_state.write_text(json.dumps(states))
        binary = self.root / "bin"
        binary.mkdir(exist_ok=True)
        script = binary / "systemctl"
        script.write_text("#!" + sys.executable + "\n" + """import json, os, pathlib, shutil, sys
state_path = pathlib.Path(os.environ['CAPTURE_TEST_UNITS'])
states = json.loads(state_path.read_text())
if 'list-units' in sys.argv:
    pattern = sys.argv[sys.argv.index('list-units') + 1]
    for name, active in states.items():
        if __import__('fnmatch').fnmatchcase(name, pattern):
            print(name + (' loaded active running fixture' if active else ' loaded inactive dead fixture'))
    sys.exit(0)
action, name = sys.argv[-2:]
with pathlib.Path(os.environ['CAPTURE_TEST_SERVICE_CALLS']).open('a') as log:
    log.write(json.dumps({'action': action, 'name': name}) + '\\n')
if action == 'is-active':
    sys.exit(0 if states.get(name) else 3)
if action == 'stop':
    states[name] = False
    if os.environ.get('CAPTURE_TEST_SETTLE'):
        pathlib.Path(os.environ['CAPTURE_TEST_SETTLE']).write_text('settled exchange\\n')
    if os.environ.get('CAPTURE_TEST_REMOVE'):
        shutil.rmtree(os.environ['CAPTURE_TEST_REMOVE'])
if action == 'start':
    if name == os.environ.get('CAPTURE_TEST_FAILED_RESTART'):
        sys.exit(1)
    states[name] = True
state_path.write_text(json.dumps(states))
if action == 'stop' and os.environ.get('CAPTURE_TEST_SIGNAL'):
    os.kill(int(os.environ['CAPTURE_TEST_PARENT']), int(os.environ['CAPTURE_TEST_SIGNAL']))
""")
        script.chmod(0o755)
        self.service_calls = self.root / "service-calls.jsonl"
        env = {"PATH": str(binary) + os.pathsep + os.environ["PATH"], "CAPTURE_TEST_UNITS": str(self.service_state),
               "CAPTURE_TEST_SERVICE_CALLS": str(self.service_calls)}
        if stop_file:
            env["CAPTURE_TEST_SETTLE"] = str(stop_file)
        if remove_on_stop:
            env["CAPTURE_TEST_REMOVE"] = str(remove_on_stop)
        if signal_on_stop:
            env["CAPTURE_TEST_SIGNAL"] = str(signal_on_stop)
        if failed_restart:
            env["CAPTURE_TEST_FAILED_RESTART"] = failed_restart
        previous = {key: os.environ.get(key) for key in env}
        os.environ.update(env)
        def restore_env():
            for key, value in previous.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
        self.addCleanup(restore_env)
        self.watchdog_launcher()

    def test_capture_uses_settled_service_data_and_preserves_previous_availability(self):
        exchange = self.source / "v1-messages-request.log"
        exchange.write_text("incomplete exchange\n")
        self.fake_services({"proxy.service": True, "unused.service": False}, stop_file=exchange)
        capture.prepare({"captures": [{"name": "proxy", "kind": "files", "paths": [str(self.source)], "units": [{"name": "proxy.service"}, {"name": "unused.service"}]}]}, self.staging)
        self.assertEqual(self.copied(exchange).read_text(), "settled exchange\n")
        self.assertEqual(json.loads(self.service_state.read_text()), {"proxy.service": True, "unused.service": False})

    def test_capture_failure_restores_service_availability_and_never_publishes_a_manifest(self):
        (self.source / "important.key").write_text("generated secret")
        self.fake_services({"executor.service": True}, remove_on_stop=self.source)
        with self.assertRaises(capture.CaptureError):
            capture.prepare({"captures": [{"name": "executor", "kind": "files", "paths": [str(self.source)], "units": [{"name": "executor.service"}]}]}, self.staging)
        self.assertTrue(json.loads(self.service_state.read_text())["executor.service"])
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    def test_final_copy_timeout_restores_availability_within_the_capture_budget(self):
        (self.source / "state").write_text("valuable state")
        real_rsync = shutil.which("rsync")
        self.fake_services({"soft-serve.service": True})
        wrapper = self.root / "bin/rsync"
        wrapper.write_text("#!" + sys.executable + "\nimport json, os, time\nif not json.load(open(os.environ['CAPTURE_TEST_UNITS']))['soft-serve.service']:\n    time.sleep(5)\nos.execv(" + repr(real_rsync) + ", [" + repr(real_rsync) + "] + __import__('sys').argv[1:])\n")
        wrapper.chmod(0o755)
        started = time.monotonic()
        with self.assertRaises(capture.CaptureError):
            capture.prepare({"captures": [{"name": "soft-serve", "kind": "files", "paths": [str(self.source)], "units": [{"name": "soft-serve.service"}]}]}, self.staging, timeout_seconds=0.4)
        self.assertLess(time.monotonic() - started, 2)
        self.assertTrue(json.loads(self.service_state.read_text())["soft-serve.service"])
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    def test_removed_optional_state_does_not_return_in_future_restore_points(self):
        (self.source / "old-profile").write_text("profile intentionally deleted")
        config = {"captures": [{"name": "profile", "kind": "files", "paths": [str(self.source)], "optional": True}]}
        capture.prepare(config, self.staging)
        shutil.rmtree(self.source)
        capture.prepare(config, self.staging)
        self.assertFalse(self.copied(self.source).exists())
        self.assertEqual(json.loads((self.staging / "capture-manifest.json").read_text())["captures"][0]["paths"], [])

    def test_interruption_restores_service_availability_and_leaves_no_complete_capture(self):
        (self.source / "request.log").write_text("valuable AI request")
        self.fake_services({"proxy.service": True}, signal_on_stop=signal.SIGTERM)
        with self.assertRaises(capture.CaptureError):
            capture.prepare({"captures": [{"name": "proxy", "kind": "files", "paths": [str(self.source)], "units": [{"name": "proxy.service"}]}]}, self.staging)
        self.assertTrue(json.loads(self.service_state.read_text())["proxy.service"])
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    def test_vanished_preseed_files_are_tolerated_before_a_complete_final_corpus_capture(self):
        logs = self.source / "logs"
        logs.mkdir()
        (logs / "main.log").write_text("diagnostic")
        (logs / "main-2026.log").write_text("rotated diagnostic")
        (logs / "v1-responses-request.log").write_text("full request response")
        (logs / "unknown-error-exchange.log").write_text("valuable error exchange")
        real_rsync = shutil.which("rsync")
        self.fake_services({"proxy.service": True})
        wrapper = self.root / "bin/rsync"
        wrapper.write_text("#!" + sys.executable + "\nimport json, os, subprocess, sys\nsubprocess.run([" + repr(real_rsync) + "] + sys.argv[1:], check=True)\nsys.exit(24 if json.load(open(os.environ['CAPTURE_TEST_UNITS']))['proxy.service'] else 0)\n")
        wrapper.chmod(0o755)
        capture.prepare({"captures": [{"name": "proxy", "kind": "files", "paths": [str(self.source)], "excludes": ["/logs/main.log", "/logs/main-*.log"], "units": [{"name": "proxy.service"}]}]}, self.staging)
        self.assertEqual(self.copied(logs / "v1-responses-request.log").read_text(), "full request response")
        self.assertEqual(self.copied(logs / "unknown-error-exchange.log").read_text(), "valuable error exchange")
        self.assertFalse(self.copied(logs / "main.log").exists())
        self.assertFalse(self.copied(logs / "main-2026.log").exists())
        self.assertTrue(json.loads(self.service_state.read_text())["proxy.service"])

    def test_user_service_without_a_running_user_manager_is_captured_without_starting_it(self):
        (self.source / "flows.json").write_text('[{"id":"recoverable flow"}]')
        capture.prepare({"captures": [{"name": "node-red", "kind": "files", "paths": [str(self.source)], "units": [{"name": "node-red.service", "type": "user", "user": "unlogged-user", "uid": 99999999}]}]}, self.staging)
        self.assertEqual(self.copied(self.source / "flows.json").read_text(), '[{"id":"recoverable flow"}]')

    def test_node_red_and_sync_writers_are_both_paused_during_final_materialization(self):
        flows = self.source / "flows.json"
        flows.write_text("earlier flow revision")
        expected = {"node-red.service": True, "git-sync-node-red-config.service": True}
        self.fake_services(expected, stop_file=flows)
        real_rsync = shutil.which("rsync")
        wrapper = self.root / "bin/rsync"
        wrapper.write_text("#!" + sys.executable + "\n" +
                           "import json, os, subprocess, sys\n" +
                           "states = json.load(open(os.environ['CAPTURE_TEST_UNITS']))\n" +
                           "if not states['node-red.service']:\n" +
                           "    assert not states['git-sync-node-red-config.service'], 'sync writer must be paused too'\n" +
                           "subprocess.run([" + repr(real_rsync) + "] + sys.argv[1:], check=True)\n")
        wrapper.chmod(0o755)
        capture.prepare({"captures": [{"name": "node-red", "kind": "files", "paths": [str(self.source)],
                                        "units": [{"name": name} for name in expected]}]}, self.staging)
        self.assertEqual(self.copied(flows).read_text(), "settled exchange\n")
        self.assertEqual(json.loads(self.service_state.read_text()), expected)

    def test_one_failed_restart_does_not_leave_other_services_stopped(self):
        (self.source / "database").write_text("recoverable state")
        self.fake_services({"other.service": True, "broken.service": True}, failed_restart="broken.service")
        with self.assertRaises(capture.CaptureError):
            capture.prepare({"captures": [{"name": "combined", "kind": "files", "paths": [str(self.source)], "units": [{"name": "other.service"}, {"name": "broken.service"}]}]}, self.staging, timeout_seconds=0.6)
        self.assertTrue(json.loads(self.service_state.read_text())["other.service"])
        self.assertFalse((self.staging / "capture-manifest.json").exists())
        self.assertTrue(list((self.staging.parent / "service-watchdogs").glob("capture-*/plan.json")))

    def test_service_recovery_retries_after_capture_reports_a_failed_restart(self):
        (self.source / "database").write_text("recoverable state")
        self.fake_services({"other.service": True, "broken.service": True}, failed_restart="broken.service")
        with self.assertRaises(capture.CaptureError):
            capture.prepare({"captures": [{"name": "combined", "kind": "files", "paths": [str(self.source)], "units": [{"name": "other.service"}, {"name": "broken.service"}]}]}, self.staging, timeout_seconds=0.6)
        self.assertTrue(json.loads(self.service_state.read_text())["other.service"])
        self.assertFalse((self.staging / "capture-manifest.json").exists())
        # Repair the command boundary after the capture has failed. The guardian
        # still owns the lease and must recover without another backup process.
        script = self.root / "bin/systemctl"
        script.write_text(script.read_text().replace("name == os.environ.get('CAPTURE_TEST_FAILED_RESTART')", "False"))
        self.await_service_states({"other.service": True, "broken.service": True})

    def test_paused_sqlite_capture_keeps_committed_attachment_references_and_files_together(self):
        database = self.source / "state.sqlite"
        with closing(sqlite3.connect(database)) as writer, writer:
            writer.execute("CREATE TABLE attachments (path TEXT)")
            writer.execute("INSERT INTO attachments VALUES ('old.txt')")
        (self.source / "old.txt").write_text("existing attachment")
        self.fake_services({"t3code.service": True})
        real_rsync = shutil.which("rsync")
        wrapper = self.root / "bin/rsync"
        wrapper.write_text("#!" + sys.executable + "\n" + "import json, os, pathlib, sqlite3, subprocess, sys\n" +
                           "subprocess.run([" + repr(real_rsync) + "] + sys.argv[1:], check=True)\n" +
                           "source = pathlib.Path(" + repr(str(self.source)) + ")\n" +
                           "if json.load(open(os.environ['CAPTURE_TEST_UNITS']))['t3code.service'] and not (source / 'new.txt').exists():\n" +
                           "    (source / 'new.txt').write_text('committed attachment')\n" +
                           "    with sqlite3.connect(source / 'state.sqlite') as writer:\n" +
                           "        writer.execute(\"INSERT INTO attachments VALUES ('new.txt')\")\n")
        wrapper.chmod(0o755)
        capture.prepare({"captures": [{"name": "t3code", "kind": "sqlite", "paths": [str(self.source)], "units": [{"name": "t3code.service"}]}]}, self.staging)
        with closing(sqlite3.connect(self.copied(database))) as restored:
            references = restored.execute("SELECT path FROM attachments ORDER BY path").fetchall()
        self.assertEqual(references, [("new.txt",), ("old.txt",)])
        self.assertEqual(self.copied(self.source / "new.txt").read_text(), "committed attachment")
        self.assertEqual(self.copied(self.source / "old.txt").read_text(), "existing attachment")
        self.assertTrue(json.loads(self.service_state.read_text())["t3code.service"])

    def test_runtime_discovered_daemon_is_paused_for_sqlite_state_and_restarted(self):
        database = self.source / "daemon.sqlite"
        with closing(sqlite3.connect(database)) as writer, writer:
            writer.execute("CREATE TABLE state (value TEXT)")
            writer.execute("INSERT INTO state VALUES ('latest committed work')")
        generated = self.source / "config.json"
        generated.write_text("incomplete exchange\n")
        self.fake_services({"daemon-revision123.service": True, "daemon-inactive.service": False}, stop_file=generated)
        capture.prepare({"captures": [{"name": "daemon", "kind": "sqlite", "paths": [str(self.source)], "discoverUnits": [{"type": "system", "pattern": "daemon-*.service"}]}]}, self.staging)
        self.assertEqual(self.copied(generated).read_text(), "settled exchange\n")
        self.assertEqual(json.loads(self.service_state.read_text()), {"daemon-revision123.service": True, "daemon-inactive.service": False})
        with closing(sqlite3.connect(self.copied(database))) as restored:
            self.assertEqual(restored.execute("SELECT value FROM state").fetchall(), [("latest committed work",)])

    def test_sqlite_capture_lock_timeout_restores_the_service_and_does_not_publish_success(self):
        database = self.source / "state.sqlite"
        writer = sqlite3.connect(database)
        self.addCleanup(writer.close)
        writer.execute("CREATE TABLE state (value TEXT)")
        writer.execute("INSERT INTO state VALUES ('committed value')")
        writer.commit()
        writer.execute("BEGIN EXCLUSIVE")
        self.fake_services({"sqlite.service": True})
        started = time.monotonic()
        with self.assertRaises(capture.CaptureError):
            capture.prepare({"captures": [{"name": "sqlite", "kind": "sqlite", "paths": [str(self.source)], "units": [{"name": "sqlite.service"}]}]}, self.staging, timeout_seconds=0.4)
        self.assertLess(time.monotonic() - started, 2)
        self.assertTrue(json.loads(self.service_state.read_text())["sqlite.service"])
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    def open_writer(self, *, source=None, ready_name="writer-ready"):
        ready = self.root / ready_name
        source = source or self.source
        program = r"""
import os, pathlib, sqlite3, sys, time
source, ready = map(pathlib.Path, sys.argv[1:])
connection = sqlite3.connect(source / 'independent.sqlite')
connection.execute('PRAGMA journal_mode=WAL')
connection.execute('CREATE TABLE attachments (path TEXT)')
connection.commit()
revision = 0
while True:
    revision += 1
    name = 'attachment-' + str(revision) + '.txt'
    (source / name).write_text('revision ' + str(revision))
    connection.execute('INSERT INTO attachments VALUES (?)', (name,))
    connection.commit()
    ready.write_text(str(revision))
    time.sleep(0.02)
"""
        process = subprocess.Popen([sys.executable, "-c", program, str(source), str(ready)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        def cleanup():
            if process.poll() is None:
                process.send_signal(signal.SIGCONT)
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            process.stderr.close()
        self.addCleanup(cleanup)
        for attempt in range(200):
            if ready.exists():
                return process
            if process.poll() is not None:
                self.fail("Fixture writer exited: " + process.stderr.read().decode())
            time.sleep(0.01)
        self.fail("Independent writer did not initialize")

    def watchdog_launcher(self):
        binary = self.root / "bin"
        binary.mkdir(exist_ok=True)
        launcher = binary / "systemd-run"
        if launcher.exists():
            return
        # Model the two production properties that matter: a distinct process
        # group/cgroup and Restart=on-failure. Only fixture processes are reached.
        supervisors = self.root / "watchdog-supervisors.jsonl"
        children = self.root / "watchdog-children.jsonl"
        supervisor = """import json, os, pathlib, subprocess, sys, time
command = sys.argv[1:]
plan = json.loads(pathlib.Path(command[-1]).read_text())
environment = dict(os.environ, CAPTURE_TEST_PARENT=str(plan['parent']['pid']))
while True:
    child = subprocess.Popen(command, env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    with pathlib.Path(CHILDREN).open('a') as log:
        log.write(json.dumps({'pid': child.pid, 'command': command}) + '\\n')
    if child.wait() == 0:
        break
    time.sleep(0.01)
""".replace("CHILDREN", repr(str(children)))
        launcher.write_text("#!" + sys.executable + "\n" + "import json, pathlib, subprocess, sys\n" +
                            "command = sys.argv[sys.argv.index('--') + 1:]\n" +
                            "child = subprocess.Popen([sys.executable, '-c', " + repr(supervisor) + ", *command], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n" +
                            "identity = pathlib.Path('/proc/' + str(child.pid) + '/stat').read_text().rsplit(')', 1)[1].split()[19]\n" +
                            "with pathlib.Path(" + repr(str(supervisors)) + ").open('a') as log:\n" +
                            "    log.write(json.dumps({'pid': child.pid, 'startTime': identity}) + '\\n')\n")
        launcher.chmod(0o755)
        previous_path = os.environ["PATH"]
        os.environ["PATH"] = str(binary) + os.pathsep + previous_path
        self.addCleanup(lambda: os.environ.__setitem__("PATH", previous_path))
        def cleanup():
            for line in supervisors.read_text().splitlines() if supervisors.exists() else []:
                recorded = json.loads(line)
                try:
                    current = pathlib.Path(f"/proc/{recorded['pid']}/stat").read_text().rsplit(")", 1)[1].split()[19]
                    if current == recorded["startTime"]:
                        os.killpg(recorded["pid"], signal.SIGKILL)
                except (FileNotFoundError, ProcessLookupError):
                    pass
        self.addCleanup(cleanup)

    def await_service_states(self, expected):
        for attempt in range(500):
            try:
                if json.loads(self.service_state.read_text()) == expected:
                    return
            except json.JSONDecodeError:
                pass
            time.sleep(0.01)
        self.fail("Managed service availability was not restored")

    def service_capture_child(self, *, timeout=2):
        config = {"captures": [{"name": "managed", "kind": "files", "paths": [str(self.source)],
                                "units": [{"name": name} for name in json.loads(self.service_state.read_text())]}]}
        program = "import importlib.util, pathlib\n" + \
            "spec = importlib.util.spec_from_file_location('fixture_capture', " + repr(capture.__file__) + ")\n" + \
            "capture = importlib.util.module_from_spec(spec); spec.loader.exec_module(capture)\n" + \
            "capture.prepare(" + repr(config) + ", pathlib.Path(" + repr(str(self.staging)) + "), timeout_seconds=" + repr(timeout) + ")\n"
        process = subprocess.Popen([sys.executable, "-c", program], start_new_session=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        def cleanup():
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            process.stdout.close()
            process.stderr.close()
        self.addCleanup(cleanup)
        return process

    def block_service_final_copy(self):
        real_rsync = shutil.which("rsync")
        marker = self.root / "service-final-copy"
        wrapper = self.root / "bin/rsync"
        wrapper.write_text("#!" + sys.executable + "\n" +
                           "import json, os, pathlib, subprocess, sys, time\n" +
                           "if not json.load(open(os.environ['CAPTURE_TEST_UNITS']))['managed.service']:\n" +
                           "    pathlib.Path(" + repr(str(marker)) + ").touch()\n" +
                           "    time.sleep(10)\n" +
                           "subprocess.run([" + repr(real_rsync) + "] + sys.argv[1:], check=True)\n")
        wrapper.chmod(0o755)
        return marker

    def test_independent_service_guardian_recovers_after_entire_capture_job_sigkill(self):
        (self.source / "state").write_text("recoverable service data")
        expected = {"managed.service": True, "inactive.service": False}
        self.fake_services(expected)
        marker = self.block_service_final_copy()
        child = self.service_capture_child()
        self.await_file(marker, child)
        os.killpg(child.pid, signal.SIGKILL)
        child.wait(timeout=5)
        self.await_service_states(expected)
        self.assertFalse((self.staging / "capture-manifest.json").exists())
        (self.root / "bin/rsync").unlink()
        capture.prepare({"captures": [{"name": "managed", "kind": "files", "paths": [str(self.source)],
                                        "units": [{"name": name} for name in expected]}]}, self.staging)
        self.assertEqual(json.loads(self.service_state.read_text()), expected)
        self.assertTrue((self.staging / "capture-manifest.json").exists())

    def test_supervised_service_guardian_recovers_after_guardian_and_capture_sigkill(self):
        (self.source / "state").write_text("recoverable service data")
        expected = {"managed.service": True, "inactive.service": False}
        self.fake_services(expected)
        marker = self.block_service_final_copy()
        child = self.service_capture_child()
        self.await_file(marker, child)
        guardian = next(json.loads(line)["pid"] for line in (self.root / "watchdog-children.jsonl").read_text().splitlines()
                        if "--service-watchdog" in json.loads(line)["command"])
        os.kill(guardian, signal.SIGKILL)
        os.killpg(child.pid, signal.SIGKILL)
        child.wait(timeout=5)
        self.await_service_states(expected)
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    def test_failed_service_guardian_launch_cannot_stop_managed_units(self):
        (self.source / "state").write_text("recoverable service data")
        self.fake_services({"managed.service": True})
        launcher = self.root / "bin/systemd-run"
        original_launcher = launcher.read_text()
        launcher.write_text("#!" + sys.executable + "\nraise SystemExit(1)\n")
        config = {"captures": [{"name": "managed", "kind": "files", "paths": [str(self.source)],
                                "units": [{"name": "managed.service"}]}]}
        with self.assertRaises(capture.CaptureError):
            capture.prepare(config, self.staging, timeout_seconds=0.4)
        self.assertTrue(json.loads(self.service_state.read_text())["managed.service"])
        self.assertFalse((self.staging / "capture-manifest.json").exists())
        launcher.write_text(original_launcher)
        capture.prepare(config, self.staging)
        self.assertTrue(json.loads(self.service_state.read_text())["managed.service"])
        self.assertTrue((self.staging / "capture-manifest.json").exists())

    def test_next_capture_refuses_a_service_with_unfinished_recovery(self):
        (self.source / "state").write_text("recoverable service data")
        self.fake_services({"managed.service": True}, failed_restart="managed.service")
        config = {"captures": [{"name": "managed", "kind": "files", "paths": [str(self.source)],
                                "units": [{"name": "managed.service"}]}]}
        with self.assertRaises(capture.CaptureError):
            capture.prepare(config, self.staging, timeout_seconds=0.6)
        self.assertFalse(json.loads(self.service_state.read_text())["managed.service"])
        with self.assertRaisesRegex(capture.CaptureError, "Previous managed-service recovery"):
            capture.prepare(config, self.staging)
        self.assertFalse((self.staging / "capture-manifest.json").exists())
        script = self.root / "bin/systemctl"
        script.write_text(script.read_text().replace("name == os.environ.get('CAPTURE_TEST_FAILED_RESTART')", "False"))
        self.await_service_states({"managed.service": True})
        capture.prepare(config, self.staging)
        self.assertTrue(json.loads(self.service_state.read_text())["managed.service"])
        self.assertTrue((self.staging / "capture-manifest.json").exists())

    def test_duplicate_guardian_launch_cannot_issue_starts_after_lease_acknowledgement(self):
        (self.source / "state").write_text("recoverable service data")
        expected = {"managed.service": True, "inactive.service": False}
        self.fake_services(expected)
        marker = self.block_service_final_copy()
        child = self.service_capture_child()
        self.await_file(marker, child)
        plan, = (self.staging.parent / "service-watchdogs").glob("capture-*/plan.json")
        duplicate = subprocess.Popen([sys.executable, str(capture.__file__), "--service-watchdog", str(plan)],
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        def cleanup_duplicate():
            if duplicate.poll() is None:
                duplicate.kill()
            duplicate.wait()
            duplicate.stdout.close()
            duplicate.stderr.close()
        self.addCleanup(cleanup_duplicate)
        duplicate.wait(timeout=1)
        self.assertEqual(duplicate.returncode, 0, duplicate.stderr.read().decode())
        os.killpg(child.pid, signal.SIGKILL)
        child.wait(timeout=5)
        self.await_service_states(expected)
        calls = [json.loads(line) for line in self.service_calls.read_text().splitlines()]
        self.assertEqual([entry for entry in calls if entry["action"] == "start"],
                         [{"action": "start", "name": "managed.service"}])
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    def test_service_guardian_recovers_when_capture_is_descheduled_past_its_deadline(self):
        (self.source / "state").write_text("recoverable service data")
        expected = {"managed.service": True, "inactive.service": False}
        self.fake_services(expected)
        marker = self.block_service_final_copy()
        child = self.service_capture_child(timeout=0.8)
        self.await_file(marker, child)
        child.send_signal(signal.SIGSTOP)
        self.await_service_states(expected)
        child.send_signal(signal.SIGCONT)
        child.wait(timeout=5)
        self.assertNotEqual(child.returncode, 0)
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    def writer_config(self):
        return {"captures": [{"name": "independent", "kind": "sqlite", "paths": [str(self.source)], "pauseOpenWriters": True, "writerUid": os.getuid()}]}

    def capture_child(self, *, setup="", timeout=1):
        program = "import importlib.util, pathlib, signal, os, time\n" + \
            "spec = importlib.util.spec_from_file_location('fixture_capture', " + repr(capture.__file__) + ")\n" + \
            "capture = importlib.util.module_from_spec(spec); spec.loader.exec_module(capture)\n" + \
            setup + "\ncapture.prepare(" + repr(self.writer_config()) + ", pathlib.Path(" + repr(str(self.staging)) + "), timeout_seconds=" + repr(timeout) + ")\n"
        process = subprocess.Popen([sys.executable, "-c", program], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        def cleanup():
            if process.poll() is None:
                process.kill()
            process.wait()
            process.stdout.close()
            process.stderr.close()
        self.addCleanup(cleanup)
        return process

    def writer_state(self, writer):
        return pathlib.Path(f"/proc/{writer.pid}/stat").read_text().rsplit(")", 1)[1].split()[0]

    def await_resumed(self, writer):
        for attempt in range(200):
            if self.writer_state(writer) not in ("T", "t"):
                self.assertIsNone(writer.poll())
                return
            time.sleep(0.01)
        self.fail("Independent writer was stranded stopped")

    def final_copy_action(self, writer, action):
        real_rsync = shutil.which("rsync")
        marker = self.root / "final-copy-started"
        wrapper = self.root / "bin/rsync"
        wrapper.write_text("#!" + sys.executable + "\n" +
                           "import os, pathlib, signal, subprocess, sys, time\n" +
                           "state = pathlib.Path('/proc/" + str(writer.pid) + "/stat').read_text().rsplit(')', 1)[1].split()[0]\n" +
                           "if state in ('T', 't'):\n" +
                           "    pathlib.Path(" + repr(str(marker)) + ").write_text('paused')\n" +
                           "\n".join("    " + line for line in action.splitlines()) + "\n" +
                           "subprocess.run([" + repr(real_rsync) + "] + sys.argv[1:], check=True)\n")
        wrapper.chmod(0o755)
        return marker

    def await_file(self, path, process):
        for attempt in range(300):
            if path.exists():
                return
            if process.poll() is not None:
                self.fail("Capture exited before the fixture boundary: " + process.stderr.read().decode())
            time.sleep(0.01)
        self.fail("Fixture boundary did not run")

    @isolated_writers
    def test_watchdog_covers_stop_scheduled_after_deadline_then_backup_sigkill(self):
        writer = self.open_writer()
        self.watchdog_launcher()
        child = self.capture_child(timeout=0.6, setup="""
native_signal = signal.pidfd_send_signal
def delayed_signal(handle, signum, *args):
    if signum == signal.SIGSTOP:
        # Model descheduling after the final deadline check but before STOP.
        time.sleep(0.7)
        native_signal(handle, signum, *args)
        os.kill(os.getpid(), signal.SIGKILL)
    return native_signal(handle, signum, *args)
signal.pidfd_send_signal = delayed_signal
""")
        child.wait(timeout=5)
        self.assertEqual(child.returncode, -signal.SIGKILL, child.stderr.read().decode())
        self.await_resumed(writer)
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    @isolated_writers
    def test_independent_writer_resumes_after_bounded_final_copy_timeout(self):
        writer = self.open_writer()
        self.watchdog_launcher()
        self.final_copy_action(writer, "time.sleep(5)")
        started = time.monotonic()
        with self.assertRaises(capture.CaptureError):
            capture.prepare(self.writer_config(), self.staging, timeout_seconds=0.6)
        self.assertLess(time.monotonic() - started, 2)
        self.await_resumed(writer)
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    @isolated_writers
    def test_independent_writer_resumes_after_capture_sigterm(self):
        writer = self.open_writer()
        self.watchdog_launcher()
        self.final_copy_action(writer, "os.kill(os.getppid(), signal.SIGTERM)")
        with self.assertRaisesRegex(capture.CaptureError, "interrupted"):
            capture.prepare(self.writer_config(), self.staging)
        self.await_resumed(writer)
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    @isolated_writers
    def test_independent_guardian_resumes_writer_after_capture_sigkill(self):
        writer = self.open_writer()
        self.watchdog_launcher()
        marker = self.final_copy_action(writer, "time.sleep(5)")
        child = self.capture_child(timeout=10)
        self.await_file(marker, child)
        self.assertEqual(self.writer_state(writer), "T")
        child.kill()
        child.wait(timeout=5)
        self.await_resumed(writer)
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    @isolated_writers
    def test_capture_preserves_a_writer_already_stopped_by_its_owner(self):
        writer = self.open_writer()
        writer.send_signal(signal.SIGSTOP)
        for attempt in range(200):
            if self.writer_state(writer) == "T":
                break
            time.sleep(0.005)
        self.assertEqual(self.writer_state(writer), "T")
        self.watchdog_launcher()
        capture.prepare(self.writer_config(), self.staging)
        self.assertEqual(self.writer_state(writer), "T")
        self.assertTrue((self.staging / "capture-manifest.json").exists())

    @isolated_writers
    def test_capture_refuses_to_suspend_its_own_writable_descriptor(self):
        self.watchdog_launcher()
        with (self.source / "unsafe-writer").open("w"):
            with self.assertRaisesRegex(capture.CaptureError, "process or ancestor"):
                capture.prepare(self.writer_config(), self.staging)
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    @isolated_writers
    def test_external_writer_resumption_invalidates_the_capture(self):
        writer = self.open_writer()
        self.watchdog_launcher()
        self.final_copy_action(writer, "os.kill(" + str(writer.pid) + ", signal.SIGCONT)")
        with self.assertRaisesRegex(capture.CaptureError, "resumed before capture completed"):
            capture.prepare(self.writer_config(), self.staging)
        self.await_resumed(writer)
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    @isolated_writers
    def test_new_writer_discovered_after_materialization_invalidates_the_capture(self):
        writer = self.open_writer()
        self.watchdog_launcher()
        ready = self.root / "new-writer-ready"
        newcomer = "import pathlib, time; stream = pathlib.Path(" + repr(str(self.source / "new-session.data")) + ").open('w'); pathlib.Path(" + repr(str(ready)) + ").touch(); time.sleep(5)"
        self.final_copy_action(writer, "subprocess.Popen([sys.executable, '-c', " + repr(newcomer) + "], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n" +
                               "while not pathlib.Path(" + repr(str(ready)) + ").exists(): time.sleep(0.005)")
        with self.assertRaisesRegex(capture.CaptureError, "new source writer"):
            capture.prepare(self.writer_config(), self.staging)
        self.await_resumed(writer)
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    @isolated_writers
    def test_capture_refuses_to_suspend_its_ancestor_writable_descriptor(self):
        self.watchdog_launcher()
        with (self.source / "unsafe-parent").open("w"):
            child = self.capture_child()
            child.wait(timeout=5)
        self.assertNotEqual(child.returncode, 0)
        self.assertIn("process or ancestor", child.stderr.read().decode())
        self.assertFalse((self.staging / "capture-manifest.json").exists())

    def fixture_identity(self, pid):
        fields = pathlib.Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        return {"pid": pid, "startTime": int(fields[19]), "uid": os.getuid()}

    def start_guardian(self, plan):
        process = subprocess.Popen([sys.executable, capture.__file__, "--resume-watchdog", str(plan)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        def cleanup():
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            process.stderr.close()
        self.addCleanup(cleanup)
        return process

    @isolated_writers
    def test_restarted_guardian_replaces_old_ack_and_releases_removed_plan(self):
        writer = self.open_writer()
        control = self.root / "lease"
        control.mkdir(mode=0o700)
        plan = control / "plan.json"
        plan.write_text(json.dumps({"parent": self.fixture_identity(os.getpid()), "writers": [self.fixture_identity(writer.pid)], "deadline": time.monotonic() + 0.2}))
        first = self.start_guardian(plan)
        ready = plan.with_suffix(".ready")
        self.await_file(ready, first)
        first.terminate()
        first.wait(timeout=3)
        self.assertTrue(plan.with_suffix(".done").exists())
        ready_time = ready.stat().st_mtime_ns
        replacement = self.start_guardian(plan)
        for attempt in range(200):
            if ready.stat().st_mtime_ns != ready_time:
                break
            time.sleep(0.01)
        self.assertNotEqual(ready.stat().st_mtime_ns, ready_time)
        self.assertFalse(plan.with_suffix(".done").exists(), "A restarted guardian must invalidate its predecessor's acknowledgement")
        shutil.rmtree(control)
        replacement.wait(timeout=2)
        self.assertEqual(replacement.returncode, 0, replacement.stderr.read().decode())
        writer.send_signal(signal.SIGSTOP)
        time.sleep(0.1)
        self.assertEqual(self.writer_state(writer), "T", "The released guardian must not resume later owner-requested stops")

    @isolated_writers
    def test_restarted_guardian_keeps_only_initially_claimed_writers(self):
        writer = self.open_writer()
        second_source = self.root / "second-source"
        second_source.mkdir()
        excluded = self.open_writer(source=second_source, ready_name="excluded-ready")
        excluded.send_signal(signal.SIGSTOP)
        for attempt in range(200):
            if self.writer_state(excluded) == "T":
                break
            time.sleep(0.005)
        control = self.root / "lease"
        control.mkdir(mode=0o700)
        plan = control / "plan.json"
        plan.write_text(json.dumps({"parent": self.fixture_identity(os.getpid()), "writers": [self.fixture_identity(writer.pid), self.fixture_identity(excluded.pid)], "deadline": time.monotonic() + 10}))
        first = self.start_guardian(plan)
        ready = plan.with_suffix(".ready")
        self.await_file(ready, first)
        self.assertEqual([entry["pid"] for entry in json.loads(ready.read_text())["writers"]], [writer.pid])
        first.terminate()
        first.wait(timeout=3)
        ready_time = ready.stat().st_mtime_ns
        replacement = self.start_guardian(plan)
        for attempt in range(200):
            if ready.stat().st_mtime_ns != ready_time:
                break
            time.sleep(0.01)
        self.assertEqual([entry["pid"] for entry in json.loads(ready.read_text())["writers"]], [writer.pid])
        plan.with_suffix(".release").touch()
        replacement.wait(timeout=3)
        self.assertEqual(self.writer_state(excluded), "T")

    @isolated_writers
    def test_independent_sqlite_writer_pauses_without_closing_and_attachments_restore_together(self):
        writer = self.open_writer()
        self.watchdog_launcher()
        real_rsync = shutil.which("rsync")
        observations = self.root / "writer-observations"
        wrapper = self.root / "bin/rsync"
        wrapper.write_text("#!" + sys.executable + "\n" + "import pathlib, subprocess, sys\n" +
                           "state = pathlib.Path('/proc/" + str(writer.pid) + "/stat').read_text().rsplit(')', 1)[1].split()[0]\n" +
                           "with pathlib.Path(" + repr(str(observations)) + ").open('a') as log: log.write(state + '\\n')\n" +
                           "subprocess.run([" + repr(real_rsync) + "] + sys.argv[1:], check=True)\n")
        wrapper.chmod(0o755)
        capture.prepare({"captures": [{"name": "independent", "kind": "sqlite", "paths": [str(self.source)], "pauseOpenWriters": True, "writerUid": os.getuid()}]}, self.staging)
        self.assertEqual(observations.read_text().splitlines()[-1], "T")
        self.assertIsNone(writer.poll())
        self.assertNotIn(pathlib.Path(f"/proc/{writer.pid}/stat").read_text().rsplit(")", 1)[1].split()[0], ("T", "t"))
        with closing(sqlite3.connect(self.copied(self.source / "independent.sqlite"))) as restored:
            references = restored.execute("SELECT path FROM attachments").fetchall()
        self.assertTrue(references)
        for (name,) in references:
            self.assertEqual(self.copied(self.source / name).read_text(), "revision " + name[11:-4])

    def test_native_sqlite_capture_restores_committed_wal_data_and_generated_keys(self):
        database = self.source / "history.sqlite"
        writer = sqlite3.connect(database)
        self.addCleanup(writer.close)
        writer.execute("PRAGMA journal_mode=WAL")
        writer.execute("PRAGMA wal_autocheckpoint=0")
        writer.execute("CREATE TABLE exchanges (request TEXT)")
        writer.execute("INSERT INTO exchanges VALUES ('valuable AI request')")
        writer.commit()
        (self.source / "data.key").write_text("generated-key")
        capture.prepare({"captures": [{"name": "history", "kind": "sqlite", "paths": [str(self.source)]}]}, self.staging)
        with closing(sqlite3.connect(self.copied(database))) as restored:
            self.assertEqual(restored.execute("SELECT request FROM exchanges").fetchall(), [("valuable AI request",)])
            self.assertEqual(restored.execute("PRAGMA integrity_check").fetchone()[0], "ok")
        self.assertEqual(self.copied(self.source / "data.key").read_text(), "generated-key")
        self.assertFalse(self.copied(self.source / "history.sqlite-wal").exists())
        self.assertFalse(self.copied(self.source / "history.sqlite-shm").exists())
        self.assertTrue((self.source / "history.sqlite-wal").exists())

    @unittest.skipUnless(shutil.which("initdb") and shutil.which("pg_dump"), "PostgreSQL test tools not installed")
    def test_all_postgres_databases_and_cluster_roles_can_be_restored(self):
        data = self.root / "pgdata"
        socket = self.root / "socket"
        socket.mkdir()
        subprocess.run(["initdb", "-D", str(data), "--no-locale", "--encoding=UTF8", "--auth=trust"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        subprocess.run(["pg_ctl", "-D", str(data), "-l", str(self.root / "postgres.log"), "-o", f"-F -p 5439 -k {socket} -c listen_addresses=''", "-w", "start"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.addCleanup(lambda: subprocess.run(["pg_ctl", "-D", str(data), "-m", "immediate", "-w", "stop"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE))
        connection = ["-h", str(socket), "-p", "5439"]
        def sql(database, statement):
            return subprocess.run(["psql", *connection, "-d", database, "-v", "ON_ERROR_STOP=1", "-At", "-c", statement], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.decode().strip()
        sql("postgres", "CREATE ROLE recovery_role")
        sql("postgres", "CREATE DATABASE extra_application")
        sql("extra_application", "CREATE TABLE requests (body TEXT); INSERT INTO requests VALUES ('critical service request')")
        capture.prepare({"captures": [{"name": "postgres", "kind": "postgres", "socket": str(socket), "port": 5439}]}, self.staging)
        manifest = json.loads((self.staging / "capture-manifest.json").read_text())["captures"][0]
        self.assertIn("extra_application", [entry["name"] for entry in manifest["databases"]])
        self.assertIn("CREATE ROLE recovery_role", (self.staging / manifest["globals"]).read_text())
        dump = next(entry for entry in manifest["databases"] if entry["name"] == "extra_application")
        sql("postgres", "CREATE DATABASE restored_application")
        subprocess.run(["pg_restore", *connection, "-d", "restored_application", "--exit-on-error", str(self.staging / dump["dump"])], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.assertEqual(sql("restored_application", "SELECT body FROM requests"), "critical service request")

    def test_private_state_symlink_is_materialized_and_metadata_can_be_restored(self):
        private = self.root / "private"
        private.mkdir(mode=0o750)
        key = private / "secret.key"
        key.write_text("service generated key")
        key.chmod(0o600)
        xattrs_supported = True
        try:
            os.setxattr(key, "user.backup-fixture", b"retain this metadata")
        except OSError as error:
            if error.errno not in (errno.ENOTSUP, errno.EOPNOTSUPP):
                raise
            xattrs_supported = False
        logical = self.source / "private-service"
        logical.symlink_to(private, target_is_directory=True)
        capture.prepare({"captures": [{"name": "private-service", "kind": "files", "paths": [str(logical)]}]}, self.staging)
        restored = self.copied(logical)
        self.assertFalse(restored.is_symlink())
        self.assertEqual((restored / "secret.key").read_text(), "service generated key")
        self.assertEqual((restored / "secret.key").stat().st_mode & 0o777, 0o600)
        if xattrs_supported:
            self.assertEqual(os.getxattr(restored / "secret.key", "user.backup-fixture"), b"retain this metadata")
        path = json.loads((self.staging / "capture-manifest.json").read_text())["captures"][0]["paths"][0]
        self.assertEqual(path["resolvedSource"], str(private))
        self.assertEqual(path["uid"], os.getuid())
        self.assertEqual(path["gid"], os.getgid())

    @unittest.skipUnless(shutil.which("nix"), "Nix not installed")
    def test_locked_configuration_inputs_remain_available_without_source_machine(self):
        flake = self.source / "configuration"
        seed = flake / "seed"
        seed.mkdir(parents=True)
        (flake / "flake.nix").write_text('{\n  inputs.seed.url = "path:./seed";\n  outputs = { seed, ... }: { recoveryValue = seed.recoveryValue; };\n}\n')
        (seed / "flake.nix").write_text('{ outputs = { ... }: { recoveryValue = "independent bootstrap"; }; }\n')
        subprocess.run(["nix", "flake", "lock", str(flake)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        capture.prepare({"captures": [{"name": "configuration", "kind": "nix", "flakePath": str(flake)}]}, self.staging)
        recovery = json.loads((self.staging / "recovery/configuration/archive.json").read_text())
        cache = self.staging / "recovery/configuration/input-cache"
        self.assertTrue(list(cache.glob("*.narinfo")))
        self.assertTrue(list((cache / "nar").iterdir()))
        shutil.rmtree(flake)
        subprocess.run(["nix", "copy", "--no-check-sigs", "--from", cache.as_uri() + "?" + urlencode({"store": (self.staging / "recovery/configuration/store-dir").read_text().strip()}), *json.loads((self.staging / "recovery/configuration/closure.json").read_text())], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        result = subprocess.run(["nix", "eval", "--offline", "--raw", recovery["path"] + "#recoveryValue"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(result.stdout.decode(), "independent bootstrap")

    def test_victoria_online_capture_materializes_backup_and_only_deletes_own_snapshot(self):
        snapshots = {"unrelated-snapshot"}
        class API(BaseHTTPRequestHandler):
            def do_GET(self):
                request = urlparse(self.path)
                if request.path == "/snapshot/create":
                    snapshots.add("capture-snapshot")
                    response = {"status": "ok", "snapshot": "capture-snapshot"}
                elif request.path == "/snapshot/delete":
                    snapshots.remove(parse_qs(request.query)["snapshot"][0])
                    response = {"status": "ok"}
                else:
                    self.send_error(404)
                    return
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
            def log_message(self, *args):
                pass
        server = HTTPServer(("127.0.0.1", 0), API)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        binary = self.root / "bin"
        binary.mkdir()
        vmbackup = binary / "vmbackup"
        vmbackup.write_text("#!" + sys.executable + "\n" + """import pathlib, sys
assert '-snapshotName=capture-snapshot' in sys.argv
path = pathlib.Path(next(arg.split('fs://', 1)[1] for arg in sys.argv if arg.startswith('-dst=fs://')))
path.mkdir(parents=True, exist_ok=True)
(path / 'metric.chunk').write_bytes(b'portable VictoriaMetrics chunk')
""")
        vmbackup.chmod(0o755)
        previous_path = os.environ["PATH"]
        os.environ["PATH"] = str(binary) + os.pathsep + previous_path
        self.addCleanup(lambda: os.environ.__setitem__("PATH", previous_path))
        capture.prepare({"captures": [{"name": "victoria", "kind": "victoria", "url": f"http://127.0.0.1:{server.server_port}", "storagePath": str(self.source)}]}, self.staging)
        self.assertEqual((self.staging / "databases/victoria/metric.chunk").read_bytes(), b"portable VictoriaMetrics chunk")
        self.assertEqual(snapshots, {"unrelated-snapshot"})

    @unittest.skipUnless(all(shutil.which(command) for command in ("victoria-metrics", "vmbackup", "vmrestore")), "VictoriaMetrics tools not installed")
    def test_native_victoria_capture_restores_queryable_metric_without_removing_unrelated_snapshot(self):
        def start_server(data):
            listener = socket.socket()
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
            listener.close()
            log = (self.root / f"victoria-{port}.log").open("wb")
            self.addCleanup(log.close)
            process = subprocess.Popen(["victoria-metrics", "-storageDataPath=" + str(data), "-httpListenAddr=127.0.0.1:" + str(port), "-loggerLevel=ERROR"], stdout=log, stderr=log)
            def stop():
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            self.addCleanup(stop)
            url = f"http://127.0.0.1:{port}"
            for attempt in range(100):
                if process.poll() is not None:
                    self.fail("Isolated VictoriaMetrics startup failed")
                try:
                    with urlopen(url + "/health", timeout=0.2) as response:
                        if response.status == 200:
                            return url
                except (OSError, URLError):
                    time.sleep(0.05)
            self.fail("Isolated VictoriaMetrics did not become healthy")
        data = self.source / "metrics"
        original_url = start_server(data)
        sample_time = int((time.time() - 120) * 1000)
        with urlopen(original_url + "/api/v1/import/prometheus", data=('backup_recovery_fixture{host="fixture"} 42 ' + str(sample_time) + "\n").encode(), timeout=10):
            pass
        with urlopen(original_url + "/snapshot/create", timeout=10) as response:
            unrelated = json.load(response)["snapshot"]
        capture.prepare({"captures": [{"name": "victoria", "kind": "victoria", "url": original_url, "storagePath": str(data)}]}, self.staging)
        with urlopen(original_url + "/snapshot/list", timeout=10) as response:
            self.assertEqual(json.load(response)["snapshots"], [unrelated])
        restored_data = self.root / "restored-metrics"
        subprocess.run(["vmrestore", "-src=fs://" + str(self.staging / "databases/victoria"), "-storageDataPath=" + str(restored_data)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        restored_url = start_server(restored_data)
        with urlopen(restored_url + "/api/v1/query?query=backup_recovery_fixture&nocache=1&time=" + str(sample_time / 1000), timeout=10) as response:
            result = json.load(response)
        self.assertEqual(result["data"]["result"][0]["value"][1], "42")

    def test_files_remain_restorable_and_direnv_is_excluded_at_every_depth(self):
        (self.source / "project").mkdir()
        (self.source / "project" / "notes.txt").write_text("uncommitted work\n")
        (self.source / "project" / ".direnv").mkdir()
        (self.source / "project" / ".direnv" / "cache").write_text("disposable")
        (self.source / ".direnv").mkdir()
        (self.source / ".direnv" / "cache").write_text("disposable")
        original = self.source / "project" / "notes.txt"
        original.chmod(0o640)
        (self.source / "link").symlink_to("project/notes.txt")
        roots = capture.prepare({"captures": [{"name": "files", "kind": "files", "paths": [str(self.source)]}]}, self.staging)
        self.assertEqual(self.copied(original).read_text(), "uncommitted work\n")
        self.assertEqual(self.copied(original).stat().st_mode & 0o777, 0o640)
        self.assertEqual(self.copied(self.source / "link").readlink(), pathlib.Path("project/notes.txt"))
        self.assertFalse(self.copied(self.source / ".direnv").exists())
        self.assertFalse(self.copied(self.source / "project/.direnv").exists())
        self.assertTrue(all(root.exists() for root in roots))
        self.assertEqual(json.loads((self.staging / "capture-manifest.json").read_text())["captures"][0]["name"], "files")

    @isolated_writers
    def test_user_service_stop_timeout_cannot_leave_a_delayed_stop_client(self):
        # A private /run makes the user-manager availability check independent
        # of the host session. Only the fixture systemctl is ever invoked.
        runtime = self.root / "runtime"
        bus = runtime / "user" / str(os.getuid()) / "bus"
        bus.parent.mkdir(parents=True)
        bus.touch()
        subprocess.run(["mount", "--bind", str(runtime), "/run"], check=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        (self.source / "state").write_text("recoverable service data")
        self.fake_services({"managed.service": True})
        attempted = self.root / "late-stop"
        armed = self.root / "stop-client"
        program = """import os, pathlib, signal, subprocess, sys, time
signal.signal(signal.SIGTERM, signal.SIG_IGN)
pathlib.Path(ARMED).write_text(str(os.getpid()))
time.sleep(1.0)
pathlib.Path(ATTEMPTED).touch()
subprocess.run(sys.argv[1:], check=True)
""".replace("ARMED", repr(str(armed))).replace("ATTEMPTED", repr(str(attempted)))
        wrapper = self.root / "bin/runuser"
        wrapper.write_text("#!" + sys.executable + "\n" +
                           "import os, subprocess, sys\n" +
                           "command = sys.argv[sys.argv.index('--') + 1:]\n" +
                           "if 'stop' in command:\n" +
                           "    raise SystemExit(subprocess.call([sys.executable, '-c', " + repr(program) + ", *command]))\n" +
                           "os.execvp(command[0], command)\n")
        wrapper.chmod(0o755)
        specification = {"captures": [{"name": "managed", "kind": "files",
                                       "paths": [str(self.source)],
                                       "units": [{"name": "managed.service", "type": "user",
                                                  "user": "fixture", "uid": os.getuid()}]}]}
        with self.assertRaises(capture.CaptureError):
            capture.prepare(specification, self.staging, timeout_seconds=0.8)
        self.assertTrue(armed.exists(), "The delayed stop client must run before timeout")
        self.await_service_states({"managed.service": True})
        time.sleep(1.1)
        self.assertFalse(attempted.exists(), "No old stop client may run after service recovery")
        self.assertTrue(json.loads(self.service_state.read_text())["managed.service"])
        self.assertFalse((self.staging / "capture-manifest.json").exists())


if __name__ == "__main__":
    unittest.main()
