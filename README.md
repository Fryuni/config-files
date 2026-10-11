# ZShutils

ZShutils is a personal Nix flake that manages NixOS machines and the shared Home
Manager environment for the `lotus` user. It brings system configuration, user
tools, custom packages, and encrypted secrets into one versioned repository.

The primary target is the `note` notebook. Shared modules also support a
remote-development server and cloud and Raspberry Pi images.

## How it fits together

[flake.nix](flake.nix) selects the package inputs and overlays, then composes each
machine from reusable modules:

- [nixos/](nixos/) provides the workstation baseline and notebook configuration.
- [servers/](servers/) provides shared server layers and host-specific modules.
- [nix-home/](nix-home/) provides the user environment, with desktop, terminal,
  development, and gaming modules selected by each configuration.
- [overlay/](overlay/) provides custom packages and access to alternate nixpkgs
  channels.

Secrets use agenix and agenix-rekey. The Nix modules are the source of truth for
exact packages and service settings; the [architecture guide](docs/architecture.md)
explains the composition and flake outputs.

`note` and `loem` use the reusable [machine backup module](nixos/modules/machine-backups.nix)
for hourly service captures and home backups every six hours into a shared restic
repository on Hetzner over SFTP on port 22; capacity monitoring runs `df` over SSH
on port 23. Each service module registers its own state directories,
capture method, and exclusions; the backup module aggregates NixOS and Home Manager
registrations. A separate systemd recovery service restarts paused services if a
backup job is killed. Restic reads registered files directly using literal file
lists and scoped exclusions; staging holds only native database exports and
recovery artifacts. Writers remain paused through upload, with a configurable
one-hour interruption limit. Selected locked flake source inputs support offline recovery
evaluation; package builds use normal network access. The dedicated SSH identity,
repository password, and backup notification token use agenix and host rekeying.
See the [backup and recovery guide](docs/backups.md) for coverage, notifications,
retention, and rollout checks. The `machine-backups-coverage` flake
check verifies registrations against each machine's actual Home Manager output,
including coordination of Node-RED's service and configured git-sync writer.

## Configurations

| Configuration | Platform | Purpose |
| --- | --- | --- |
| `note` | `x86_64-linux` | Workstation and notebook |
| `loem` | `x86_64-linux` | Hosted services and remote development |
| `gce-automation` | `x86_64-linux` | Google Compute automation image |
| `rpi3` | `aarch64-linux` | Raspberry Pi 3 SD image |
| `lotus@note` | `x86_64-linux` | Standalone Home Manager environment |

## Working with the configuration

Use Nix with flakes enabled and direnv; the repository's `.envrc` loads the flake
environment. From the repository root:

```bash
direnv allow
nix run .#build      # Build the notebook Home Manager configuration
nix run .#os-build   # Build the notebook NixOS configuration
nix run .#diff       # Inspect home environment changes
nix run .#os-diff    # Inspect system changes
```

These commands build or inspect changes without applying them. See
[maintenance and validation](docs/maintenance.md) for other hosts, checks,
formatting, and dependency updates.

`nh` provides build progress and a package delta for both Home Manager and NixOS.
The `nix-output-monitor` flake check replays log events to verify compatibility
with Determinate Nix and preserve build and download reporting.

## Documentation

| Topic | Guide |
| --- | --- |
| Module composition, machines, users, and flake outputs | [Architecture](docs/architecture.md) |
| Builds, checks, package updates, and CI | [Maintenance and validation](docs/maintenance.md) |
| Encryption, host identities, and rekeying | [Secrets](docs/secrets.md) |
| Backup policy, operation, service coverage, and recovery | [Backups and recovery](docs/backups.md) |
| Desktop sessions, shell display access, and tray icons | [Notebook desktop](docs/desktop.md) |
| Forgejo, Actions runners, Executor, metrics, and private networking | [Hosted services and Tailnet access](docs/services.md) |
| T3 Code, Claude Code, and Herdr configuration | [AI tools](docs/ai-tools.md) |
| Cache authentication, upload queues, and telemetry | [Shared Nix cache](docs/nix-store-cache.md) |
