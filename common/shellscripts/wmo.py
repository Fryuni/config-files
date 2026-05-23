#!/usr/bin/env python3

import os
import subprocess
import sys


def git_lines(*args: str) -> list[str]:
    result = subprocess.run(
        ["git", *args],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    return [
        line.strip()
        for line in result.stdout.splitlines()
        if line.strip()
    ]


def choose_branch(options: list[str]) -> str:
    try:
        result = subprocess.run(
            ["gum", "filter", "--height=10", "--no-show-help", *options],
            check=False,
            stdout=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError:
        print("wmo: gum is required to choose a branch interactively", file=sys.stderr)
        sys.exit(127)

    branch_name = result.stdout.strip()
    if result.returncode != 0:
        print("wmo: no branch selected", file=sys.stderr)
        sys.exit(result.returncode or 1)

    return branch_name


def main() -> None:
    branch_name = sys.argv[1] if len(sys.argv) > 1 else None
    args = sys.argv[2:] if branch_name is not None else []

    current_branch = subprocess.run(
        ["git", "branch", "--show-current"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    ).stdout.strip()

    local_branches = [
        ref
        for ref in git_lines("branch", "--format=%(refname:short)")
        if ref != current_branch
    ]

    remote_branches = [
        ref.removeprefix("refs/remotes/")
        for ref in git_lines("branch", "--remote", "--format=%(refname)")
        if ref.startswith("refs/remotes/") and not ref.endswith("/HEAD")
    ]

    all_options = [
        *local_branches,
        *remote_branches,
    ]

    if not branch_name or branch_name not in all_options:
        branch_name = choose_branch(all_options)

    if not branch_name:
        print("wmo: no branch selected", file=sys.stderr)
        sys.exit(1)

    if branch_name in remote_branches:
        remote_name, branch_name = branch_name.split("/", 1)
        subprocess.run(
            ["git", "branch", "--track", branch_name, f"{remote_name}/{branch_name}"],
            check=True,
        )

    try:
        os.execvp(
            "workmux",
            ["workmux", "add", "--open-if-exists", branch_name, *args],
        )
    except FileNotFoundError:
        print("wmo: workmux is required", file=sys.stderr)
        sys.exit(127)


if __name__ == "__main__":
    main()
