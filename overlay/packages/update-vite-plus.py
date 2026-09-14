#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 git
"""Update the Vite+ release binaries and npm toolchain as one validated change."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import urllib.request


def output(*args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def replace_once(pattern, replacement, text):
    result, count = re.subn(pattern, lambda _: replacement, text, flags=re.MULTILINE)
    if count != 1:
        raise ValueError(f"Expected exactly one match for {pattern!r}, found {count}")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-commit", action="store_true", help="leave the update uncommitted")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[2]
    os.chdir(repo)
    paths = [
        Path("overlay/packages/vite-plus.nix"),
        Path("overlay/packages/vite-plus/package.json"),
        Path("overlay/packages/vite-plus/package-lock.json"),
    ]
    originals = {path: path.read_bytes() for path in paths}
    package = originals[paths[0]].decode()
    manifest = json.loads(originals[paths[1]])
    lock = json.loads(originals[paths[2]])
    versions = re.findall(r'^  version = "([^"]+)";$', package, re.MULTILINE)
    if len(versions) != 1:
        raise ValueError("Expected exactly one Vite+ version in the package")
    current = versions[0]
    if any(version != current for version in [
        manifest["version"], manifest["dependencies"]["vite-plus"], lock["version"],
        lock["packages"][""]["version"], lock["packages"][""]["dependencies"]["vite-plus"],
        lock["packages"]["node_modules/vite-plus"]["version"],
    ]):
        raise ValueError("The current Vite+ package and npm lockfile versions disagree")

    headers = {"Accept": "application/vnd.github+json", "User-Agent": "vite-plus-nix-updater"}
    if token := os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        "https://api.github.com/repos/voidzero-dev/vite-plus/releases/latest", headers=headers
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        release = json.load(response)
    tag = release["tag_name"]
    if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", tag) or release["prerelease"] or release["draft"]:
        raise ValueError(f"Expected a stable Vite+ release, got {tag!r}")
    version = tag[1:]
    if version == current:
        print(f"Vite+ {version} is already current; nothing to update.")
        return
    if not args.no_commit and output("git", "status", "--porcelain", "--", *map(str, paths)):
        raise ValueError("Vite+ package files have local changes; use --no-commit to preserve them for review")

    print(f"Updating Vite+ {current} -> {version}", flush=True)
    assets = {asset["name"] for asset in release["assets"]}
    target_pattern = r'target = "([^"]+)";\s+hash = "[^"]+";'
    targets = re.findall(target_pattern, package)
    if not targets:
        raise ValueError("No Vite+ binary targets found in the package")
    for target in targets:
        if f"vp-{target}.tar.gz" not in assets:
            raise ValueError(f"Release {tag} is missing the {target} binary")
    for target in targets:
        url = f"https://github.com/voidzero-dev/vite-plus/releases/download/{tag}/vp-{target}.tar.gz"
        fetched = json.loads(output("nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url))
        package = replace_once(
            rf'target = "{re.escape(target)}";\s+hash = "[^"]+";',
            f'target = "{target}";\n      hash = "{fetched["hash"]}";', package,
        )
    package = replace_once(r'^  version = "[^"]+";$', f'  version = "{version}";', package)

    system = output("nix", "eval", "--raw", "--impure", "--expr", "builtins.currentSystem")

    def tool(name):
        return Path(output("nix", "build", "--no-link", "--print-out-paths", f".#legacyPackages.{system}.{name}"))

    node = tool("nodejs_26")
    prefetch = tool("prefetch-npm-deps")
    with tempfile.TemporaryDirectory(prefix="update-vite-plus-") as temp:
        temp = Path(temp)
        npm_dir = temp / "vite-plus"
        npm_dir.mkdir()
        manifest["version"] = version
        manifest["dependencies"]["vite-plus"] = version
        (npm_dir / "package.json").write_text(json.dumps(manifest, indent=2) + "\n")
        env = dict(os.environ, PATH=f"{node}/bin{os.pathsep}{os.environ['PATH']}")
        # No old lockfile or node_modules: npm must retain every platform's
        # optional bindings, not just those installed on the updater's host.
        subprocess.check_call([
            str(node / "bin/npm"), "install", "--package-lock-only", "--ignore-scripts",
            "--include=optional", "--no-audit", "--no-fund", "--cache", str(temp / "npm-cache"),
        ], cwd=npm_dir, env=env)
        lock_path = npm_dir / "package-lock.json"
        updated_lock = json.loads(lock_path.read_text())
        if updated_lock["packages"]["node_modules/vite-plus"]["version"] != version:
            raise ValueError("npm resolved a different Vite+ version")
        # Keep this format in sync with npmDeps.fetcherVersion in vite-plus.nix.
        npm_hash = output(str(prefetch / "bin/prefetch-npm-deps"), str(lock_path),
                          env=dict(env, NPM_FETCHER_VERSION="1"))
        if not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", npm_hash):
            raise ValueError(f"Invalid npm dependency hash: {npm_hash!r}")
        package = replace_once(
            r'^      hash = "[^"]+";(?=\n    \};\n\n    nativeBuildInputs)',
            f'      hash = "{npm_hash}";', package,
        )
        candidate = temp / "vite-plus.nix"
        candidate.write_text(package)
        # Build the temporary package with this flake's locked dependencies.
        # Fetch/build failures leave the repository and its index untouched.
        subprocess.check_call([
            "nix", "build", "--no-link", "--impure", "--expr",
            "{ repo, package, system }: (builtins.getFlake repo).legacyPackages.${system}.callPackage package {}",
            "--argstr", "repo", str(repo), "--argstr", "package", str(candidate),
            "--argstr", "system", system,
        ])
        if any(path.read_bytes() != contents for path, contents in originals.items()):
            raise ValueError("Vite+ files changed while the update was running; leaving them untouched")
        for source, destination in zip([candidate, npm_dir / "package.json", lock_path], paths):
            shutil.copyfile(source, destination)

    if not args.no_commit:
        subprocess.check_call(["git", "add", "--", *map(str, paths)])
        subprocess.check_call(["git", "commit", "-m", f"vite-plus: {current} -> {version}", "--", *map(str, paths)])
    print(f"Updated Vite+ to {version}.")


if __name__ == "__main__":
    main()
