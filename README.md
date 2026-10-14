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
recovery artifacts. CLIProxyAPI and T3 Code remain online, with consistent SQLite
exports for T3 and accepted live-file races for associated state and request
exchanges. Other writers requiring pauses remain paused through upload, with a
configurable one-hour interruption limit. Selected locked flake source inputs
support offline recovery evaluation; package builds use normal network access. The dedicated SSH identity,
repository password, and backup notification token use agenix and host rekeying.
Backup jobs push their persisted status directly to VictoriaMetrics through its
portable Tailnet service; a separate five-minute heartbeat also retries delivery
without contacting the backup repository or interrupting captures.
See the [backup and recovery guide](docs/backups.md) for coverage, notifications,
retention, and rollout checks. The `machine-backups-coverage` flake
check verifies registrations against each machine's actual Home Manager output,
including coordination of Node-RED's service and configured git-sync writer.

Loem hosts Grafana at `https://grafana.loem.lferraz.dev` through the private
Tailnet Caddy proxy. VictoriaMetrics ingestion retains its independent Tailscale
service name, `victoriametrics.rudd-agama.ts.net`, so collectors do not depend on
the storage host's identity. Versioned dashboards cover fleet health, Tailnet
traffic, ingestion and hosted services, automated backup freshness and recovery
evidence, bare-metal server thermals and hardware, notebook hardware, and the shared Nix
cache. Grafana automation credentials use agenix and host rekeying. See
[metrics operation](docs/services.md#metrics) and the [coverage audit](docs/metrics-audit.md).

Loem also hosts Hollama at `https://chat.loem.lferraz.dev` through the private
Tailnet proxy, connected directly to its local CLIProxyAPI for model testing.
It needs no sign-in or server database: chats and settings stay in each browser's
local storage. See [Hollama operation and validation](docs/ai-tools.md#hollama).

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

The Bun scripts in [common/shellscripts/](common/shellscripts/) are installed in
`~/.local/bin` without their extensions. With `fj` and `gh` authenticated,
`fj-to-github <forgejo-host>/<owner>/<repo> <github-owner>/<repo>` configures an
SSH push mirror and a writable GitHub deploy key. `fj-fork-square <github-owner>/<repo>
[forgejo-host]` creates an upstream pull mirror in the `mirror` namespace, forks
it under your Forgejo account, and push-mirrors that fork to your GitHub fork.
The default Forgejo host is `git.fryuni.dev`; rerunning either script resumes a
partial setup. Push mirrors sync on commits and every eight hours.
Private sources require private targets, including existing upstream pull mirrors.

`nh` provides build progress and a package delta for both Home Manager and NixOS.
The `nix-output-monitor` flake check replays log events to verify compatibility
with Determinate Nix and preserve build and download reporting.
The `metrics-dashboards` check runs dashboard queries in a disposable VictoriaMetrics
instance to verify collection gaps and restore evidence from another machine.

## Documentation

| Topic | Guide |
| --- | --- |
| Module composition, machines, users, and flake outputs | [Architecture](docs/architecture.md) |
| Builds, checks, package updates, and CI | [Maintenance and validation](docs/maintenance.md) |
| Encryption, host identities, and rekeying | [Secrets](docs/secrets.md) |
| Backup policy, operation, service coverage, and recovery | [Backups and recovery](docs/backups.md) |
| Desktop sessions, shell display access, and tray icons | [Notebook desktop](docs/desktop.md) |
| Forgejo, Actions runners, Executor, metrics, and private networking | [Hosted services and Tailnet access](docs/services.md) |
| T3 Code, Hollama, Claude Code, and Herdr configuration | [AI tools](docs/ai-tools.md) |
| Cache authentication, upload queues, and telemetry | [Shared Nix cache](docs/nix-store-cache.md) |
