"""Offline regression tests for Vite+ release selection through the updater."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
import urllib.error


REPO = Path(__file__).resolve().parents[1]
API = "https://api.github.com/repos/voidzero-dev/vite-plus/releases"


def release(tag, **flags):
    return {"tag_name": tag, "prerelease": False, "draft": False, "assets": [], **flags}


class ReleaseSelectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        packages = self.repo / "overlay/packages"
        packages.mkdir(parents=True)
        for name in ["update-vite-plus.py", "vite-plus.nix"]:
            shutil.copyfile(REPO / "overlay/packages" / name, packages / name)
        shutil.copytree(REPO / "overlay/packages/vite-plus", packages / "vite-plus")
        spec = importlib.util.spec_from_file_location("updater", packages / "update-vite-plus.py")
        self.updater = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.updater)
        self.addCleanup(os.chdir, Path.cwd())
        current = json.loads((packages / "vite-plus/package.json").read_text())["version"]
        self.stable = release(f"v{current}")
        # Actual metadata returned for the release that broke CI run 200.
        self.rc = release("v1.0.0-rc.1")
        self.originals = {p: p.read_bytes() for p in packages.rglob("*") if p.is_file()}

    def run_updater(self, responses, *, no_commit=False):
        def respond(request, timeout):
            self.assertEqual(timeout, 60)
            value = responses[request.full_url]
            if isinstance(value, Exception):
                raise value
            return io.BytesIO(json.dumps(value).encode())

        with patch.object(self.updater.urllib.request, "urlopen", side_effect=respond) as fetch, \
                patch.object(self.updater.subprocess, "check_call") as call, \
                patch.object(self.updater.subprocess, "check_output") as output, \
                patch("sys.argv", ["update-vite-plus.py"] + (["--no-commit"] if no_commit else [])), \
                contextlib.redirect_stdout(io.StringIO()) as stdout:
            try:
                self.updater.main()
            finally:
                call.assert_not_called()
                output.assert_not_called()
                for path, contents in self.originals.items():
                    self.assertEqual(path.read_bytes(), contents)
            return stdout.getvalue(), fetch.call_count

    def test_stable_latest_is_already_current(self):
        stdout, requests = self.run_updater({f"{API}/latest": self.stable})
        self.assertIn("already current; nothing to update", stdout)
        self.assertEqual(requests, 1)

    def test_mislabeled_rc_falls_back_to_current_stable(self):
        stdout, _ = self.run_updater({
            f"{API}/latest": self.rc,
            f"{API}?per_page=100&page=1": [self.rc, release("v1.0.0-rc.0"), self.stable],
        })
        self.assertIn("already current; nothing to update", stdout)

    def test_paginates_past_unstable_and_draft_releases(self):
        stdout, requests = self.run_updater({
            f"{API}/latest": self.rc,
            f"{API}?per_page=100&page=1": [
                self.rc, release("nightly"), release("v9.0.0", prerelease=True),
                release("v8.0.0", draft=True),
            ] * 25,
            f"{API}?per_page=100&page=2": [self.stable],
        })
        self.assertIn("already current; nothing to update", stdout)
        self.assertEqual(requests, 3)

    def test_new_stable_still_reaches_asset_validation(self):
        with self.assertRaisesRegex(ValueError, "Release v99.0.0 is missing"):
            self.run_updater({
                f"{API}/latest": self.rc,
                f"{API}?per_page=100&page=1": [self.rc, release("v99.0.0"), self.stable],
            }, no_commit=True)

    def test_no_stable_release_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "No stable Vite\\+ release found"):
            self.run_updater({
                f"{API}/latest": self.rc,
                f"{API}?per_page=100&page=1": [self.rc],
                f"{API}?per_page=100&page=2": [],
            })

    def test_api_failure_is_not_silently_skipped(self):
        with self.assertRaises(urllib.error.HTTPError):
            self.run_updater({
                f"{API}/latest": self.rc,
                f"{API}?per_page=100&page=1": urllib.error.HTTPError(API, 403, "Forbidden", {}, None),
            })


if __name__ == "__main__":
    unittest.main()
