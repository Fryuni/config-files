"""Run dashboard queries against isolated VictoriaMetrics data and collection gaps."""

import json
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from urllib.parse import urlencode
from urllib.request import Request, urlopen


DASHBOARDS = Path(sys.argv.pop(1))
CURRENT = ["fleet-system", "tailnet-services", "monitoring-pipeline", "note-hardware", "bare-metal-hardware"]


class DashboardQueriesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="metrics-dashboards-")
        cls.addClassCleanup(cls.temporary.cleanup)
        root = Path(cls.temporary.name)
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        cls.url = "http://127.0.0.1:%d" % port
        cls.log = (root / "victoria.log").open("w+")
        cls.addClassCleanup(cls.log.close)
        cls.process = subprocess.Popen([
            shutil.which("victoria-metrics"), "-httpListenAddr=127.0.0.1:%d" % port,
            "-storageDataPath=" + str(root / "data"), "-memory.allowedBytes=64MiB",
            # Deliberately retain old raw samples: the queries must enforce their
            # own freshness bound rather than pass only with short backend lookback.
            "-search.minStalenessInterval=30m",
        ], stdout=cls.log, stderr=cls.log)
        cls.addClassCleanup(cls.stop)
        deadline = time.monotonic() + 15
        while True:
            try:
                with urlopen(cls.url + "/health", timeout=1):
                    break
            except OSError:
                if cls.process.poll() is not None or time.monotonic() > deadline:
                    cls.log.seek(0)
                    raise AssertionError(cls.log.read())
                time.sleep(0.05)
        cls.now = int(time.time())
        samples = []

        def sample(name, value, extra=None):
            labels = {"host": "fixture", "instance": "fixture", "job": "node", **(extra or {})}
            fields = ",".join(key + "=" + json.dumps(value) for key, value in labels.items())
            for offset in [75, 15]:
                samples.append(name + "{" + fields + "} " + str(value) + " " + str((cls.now - offset) * 1000))

        for job in ["node", "tailscale", "vmagent"]:
            sample("up", 1, {"job": job})
        sample("node_cpu_seconds_total", 300, {"mode": "idle", "cpu": "0"})
        sample("node_memory_MemAvailable_bytes", 50)
        sample("node_memory_MemTotal_bytes", 100)
        filesystem = {"mountpoint": "/", "fstype": "ext4", "device": "/dev/fixture"}
        sample("node_filesystem_avail_bytes", 70, filesystem)
        sample("node_filesystem_size_bytes", 100, filesystem)
        sample("node_boot_time_seconds", cls.now - 3600)
        sample("tailscaled_health_messages", 0, {"job": "tailscale", "type": "warning"})
        for path in ["direct", "derp"]:
            sample("tailscaled_inbound_bytes_total", 100, {"job": "tailscale", "path": path})
        sample("tailscaled_serve_inbound_bytes_total", 100, {"job": "tailscale"})
        sample("scrape_samples_scraped", 100)
        sample("node_textfile_mtime_seconds", cls.now - 60, {"file": "fixture.prom"})
        sample("vmagent_remotewrite_pending_data_bytes", 0, {"job": "vmagent"})
        battery = {"power_supply": "BAT0"}
        sample("node_power_supply_capacity", 40, battery)
        sample("node_power_supply_charge_full", 2, battery)
        sample("node_power_supply_charge_full_design", 4, battery)
        sample("node_power_supply_online", 1, {"power_supply": "AC"})
        sensor = {"chip": "platform_coretemp_0", "sensor": "temp1"}
        sample("node_hwmon_temp_celsius", 55, sensor)
        sample("node_hwmon_temp_crit_celsius", 100, sensor)
        sample("node_hwmon_temp_crit_alarm_celsius", 0, sensor)
        sample("node_cpu_package_throttles_total", 0, {"package": "0"})
        for observer in ["loem", "recovery"]:
            fields = 'job="machine-backups",host="' + observer + '",source_host="note",scope="home"'
            for suffix, value in [
                ("timestamp_seconds", cls.now - 86400), ("duration_seconds", 42),
                ("partial", 0), ("application_verified", 0),
            ]:
                samples.append("machine_backup_restore_rehearsal_" + suffix + "{" + fields + "} " +
                               str(value) + " " + str((cls.now - 15) * 1000))
        with urlopen(Request(cls.url + "/api/v1/import/prometheus", data=("\n".join(samples) + "\n").encode()), timeout=5):
            pass
        # Imports are asynchronous. Flush only this disposable database before
        # querying; no fixture or administrative request reaches production.
        with urlopen(cls.url + "/internal/force_flush", timeout=5):
            pass

    @classmethod
    def stop(cls):
        cls.process.terminate()
        try:
            cls.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            cls.process.kill()
            cls.process.wait(timeout=5)

    def query(self, expr, host="fixture", at=None, **params):
        expr = expr.replace('$host', host).replace('$__rate_interval', '1m')
        params.update(query=expr, time=self.now if at is None else at, nocache=1)
        with urlopen(self.url + "/api/v1/query?" + urlencode(params), timeout=5) as response:
            result = json.load(response)
        self.assertEqual(result["status"], "success", result)
        return result["data"]["result"]

    def dashboard(self, name):
        return json.loads((DASHBOARDS / (name + ".json")).read_text())

    def test_current_summaries_do_not_reuse_history_when_collection_stops(self):
        count = 0
        for name in CURRENT:
            for panel in self.dashboard(name)["panels"]:
                if panel["type"] != "stat":
                    continue
                for target in panel["targets"]:
                    with self.subTest(dashboard=name, panel=panel["title"]):
                        self.assertTrue(target["instant"])
                        self.assertFalse(target["range"])
                        self.assertEqual(panel["options"]["graphMode"], "none")
                        self.assertTrue(self.query(target["expr"]))
                        self.assertEqual(self.query(target["expr"], at=self.now + 130), [])
                        count += 1
        self.assertEqual(count, 20)
        # The stale healthy values are still available to the backend and to
        # historical queries, so absence above really comes from the query bound.
        stale = self.query('node_hwmon_temp_crit_alarm_celsius{host="fixture"}', at=self.now + 130)
        self.assertEqual(float(stale[0]["value"][1]), 0)
        self.assertTrue(self.query('last_over_time(up{host="fixture",job="tailscale"}[6h])', at=self.now + 130))

    def test_fresh_hardware_values_and_failed_scrapes_remain_visible(self):
        panels = self.dashboard("bare-metal-hardware")["panels"]
        for panel, expected in zip(panels[:4], [55, 45, 0, 0]):
            result = self.query(panel["targets"][0]["expr"])
            self.assertEqual(float(result[0]["value"][1]), expected)
        exporter = self.dashboard("tailnet-services")["panels"][0]["targets"][0]["expr"]
        # A current failed scrape should display zero, distinct from absent data.
        sample = 'up{host="failed",job="tailscale"} 0 %d\n' % ((self.now - 15) * 1000)
        with urlopen(Request(self.url + "/api/v1/import/prometheus", data=sample.encode()), timeout=5):
            pass
        with urlopen(self.url + "/internal/force_flush", timeout=5):
            pass
        self.assertEqual(float(self.query(exporter, host="failed")[0]["value"][1]), 0)

    def test_cross_host_restore_evidence_follows_the_restored_machine(self):
        count = 0
        for panel in self.dashboard("automated-backups")["panels"]:
            for target in panel.get("targets", []):
                if "machine_backup_restore_rehearsal_" not in target["expr"]:
                    continue
                with self.subTest(panel=panel["title"], target=target["refId"]):
                    restored = self.query(target["expr"], host="note")
                    self.assertEqual({s["metric"]["host"] for s in restored}, {"loem", "recovery"})
                    self.assertTrue(all(s["metric"]["source_host"] == "note" for s in restored))
                    self.assertEqual(self.query(target["expr"], host="loem"), [])
                    self.assertIn("{{host}}", target["legendFormat"])
                    self.assertIn("{{source_host}}", target["legendFormat"])
                    count += 1
        self.assertEqual(count, 4)


if __name__ == "__main__":
    unittest.main()
