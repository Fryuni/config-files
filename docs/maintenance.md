# Maintenance and validation

[Project overview](../README.md) · [Architecture](architecture.md)

Run local commands from the repository root. The `.envrc` enables nix-direnv; allow it
with `direnv allow`, or prefix a command with `direnv exec .` to use the flake
environment.

## Build and inspect changes

The apps in `commands.nix` provide local build and diff helpers:

```bash
nix run .#build      # Build Home Manager for lotus@note
nix run .#os-build   # Build NixOS for note
nix run .#diff       # Compare the notebook home environment
nix run .#os-diff    # Compare the notebook system
```

These commands do not activate a configuration. Build another host by selecting its
flake output, for example:

```bash
nix build .#nixosConfigurations.loem.config.system.build.toplevel --no-link
```

New files must be staged with `git add <file>` before Nix flake commands can see them.
Build and inspect the affected output before applying changes; activation is a separate
user step.

## Formatting

```bash
nix fmt .           # Format Nix files with alejandra
nix run .#fmt       # Run statix fix, then alejandra
```

## Dependency updates

```bash
just update                 # Update flake inputs and custom overlay packages
just update-flake           # Update flake.lock only
just update-overlays        # Update registered overlay packages
just update-package <name>  # Update one package or family
```

The update recipes and package updaters can stage files and create commits. Use the
no-commit updater commands below when reviewing candidate package changes.

### Package registry and updaters

All custom overlay package updates derive from `overlay/registry.nix`; there is no
hand-maintained package list anywhere else:

- `just update-overlays` dispatches every registry entry that declares an update
  strategy, in deterministic name order, aborting on the first failure.
- `just update-package <name>` (or `overlay/update.sh <name>`) dispatches a single entry
  for targeted maintenance or diagnosis.
- Registry entries pick one of three strategies: ordinary `nix-update` against
  `packages.x86_64-linux` using short package names (full argument flexibility), a
  specialized family updater (`overlay/pulumi/update.sh`,
  `overlay/rustPackages/update.mjs`), or no automatic updater for intentionally pinned
  packages (for example the terminal `terraformOSS` pin). Short names also become the
  update commit subjects, without rewriting commits.
- Adding an ordinary package means dropping `<name>.nix` into `overlay/packages/` and
  adding one registry entry; exposure and update dispatch follow automatically.
- `just update-package forgejo` fetches the latest commit on the fork's `forgejo`
  branch, then refreshes the source, Go vendor, and npm dependency hashes. It does not
  select release tags. Run `overlay/packages/update-forgejo.sh --no-commit` to update
  the pin without committing.
- `just update-package vite-plus` selects the latest stable GitHub release, refreshes
  all supported binary hashes and the npm lockfile/dependency hash, and builds the
  candidate before replacing the package files and committing them as
  `vite-plus: {old} -> {new}`. If GitHub's latest release has a prerelease tag (even
  when marked stable), the updater searches paginated release history for a stable tag,
  excluding drafts and prereleases. Unchanged releases are skipped. It also runs through
  `just update`; use `overlay/packages/update-vite-plus.py --no-commit` to review an
  update without staging or committing it.

### Package inputs

- `google-workspace-cli` follows the root `nixpkgs` input so its `gws` package uses the
  same upstream Cargo fetcher fixes as the main package set.
- The shared Tailscale module uses `pkgs.master.tailscale`; update it through the
  `nixpkgs-master` flake input.

## Continuous integration

Forgejo Actions automate maintenance on the self-hosted Nix runner. The workflows live
in `.forgejo/workflows/validate.yml` and `.forgejo/workflows/update.yml`.

- Pull requests and pushes to `main` build the `note` and `loem` NixOS configurations,
  the `lotus@note` Home Manager generation, and all `x86_64-linux` flake checks,
  including reusable-module checks and offline Vite+ updater regression tests. The
  workflow currently omits `gce-automation`, and the `rpi3` SD-image target is commented
  out.
- A weekly and manually dispatched update workflow runs `just update` from `main`.
  Serialized runs force-push the existing update PR branch, or create
  `automation/update-dependencies` and a PR when needed. It reuses branches from the
  previous per-run naming scheme, closes duplicate update PRs, and closes stale update
  PRs when there are no changes.
- Update PRs are then scheduled for a rebase-then-fast-forward auto-merge (the `rebase`
  style) that lands once every check succeeds, deleting the branch afterwards. That
  style creates no commit of its own, so no merge title or body is sent. The workflow
  first waits for the pushed head to leave the conflict-checking state and for its
  commit statuses to appear, because the Forgejo fork treats a commit with no workflow
  runs as ready to merge; scheduling earlier could merge before CI starts. An
  already-scheduled PR is not an error, and the workflow fails rather than leaving a PR
  unscheduled.
- Publication uses a short-lived OIDC JWT for Git and API authentication, following the
  [Authorized Application example](https://git.fryuni.dev/Fryuni/llm-agents.nix/src/branch/main/.forgejo/workflows/update.yml).
  The repository Actions variable `TOKEN_AUDIENCE` identifies the application audience.
  The application must allow this repository, `.forgejo/workflows/update.yml`,
  `refs/heads/main`, and the `schedule` and `workflow_dispatch` events, with repository
  and pull-request write access. Checkout persists no credentials, and the publication
  JWT is minted after the updaters finish; `UPDATE_FORGEJO_TOKEN` is no longer used. The
  update step receives the `READ_ONLY_GITHUB_TOKEN` Actions secret as `GITHUB_TOKEN` for
  authenticated GitHub API requests to reduce rate limiting.

## Choosing validation

Prefer the narrow output that matches the change:

- Evaluate or build the affected `homeConfigurations` output for Home Manager-only
  changes.
- Evaluate or build the affected `nixosConfigurations.<machine>` output for host
  changes.
- Run the relevant `checks` entry when changing a reusable module covered by `tests/`.
- Run `nix build .#checks.x86_64-linux.nix-output-monitor` for `nh` progress
  compatibility. The overlay backports upstream handling of unknown activity and
  result types from [nom PR #321](https://github.com/maralorn/nix-output-monitor/pull/321)
  until the fix reaches nixpkgs. The replay also verifies build logs and download
  reporting, and that malformed known events still produce errors.
  The override asserts version `2.2.0`, so an upstream version change requires
  reviewing whether the patch is still needed before updating or removing the assertion.
- Run `nix build .#checks.x86_64-linux.vite-plus-updater` for the Vite+ updater, or
  `python3 -B tests/vite-plus-updater.py` for a fast offline replay without Nix.
- Run `nix build .#checks.x86_64-linux.machine-backups-module` for evaluated backup
  module behavior, `nix build .#checks.x86_64-linux.machine-backups-coverage` for
  actual `note`/`loem` registrations (including the standalone Home Manager bridge),
  and `nix build .#checks.x86_64-linux.machine-backups-runtime` for isolated capture, database recovery and restic operations. See the
  [backup guide](backups.md) for production rollout checks.
- Use the diff helpers to inspect prospective system or Home Manager changes before
  applying them.

## Documentation

Keep the [README](../README.md) overview current when machine definitions, users, module
composition, flake outputs, secrets, or validation workflows change. Put
feature-specific settings and operational detail in the relevant topic guide, and use
the Nix modules as the source of truth for exact configuration.
