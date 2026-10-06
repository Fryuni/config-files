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

## Documentation

| Topic | Guide |
| --- | --- |
| Module composition, machines, users, and flake outputs | [Architecture](docs/architecture.md) |
| Builds, checks, package updates, and CI | [Maintenance and validation](docs/maintenance.md) |
| Encryption, host identities, and rekeying | [Secrets](docs/secrets.md) |
| Desktop sessions, shell display access, and tray icons | [Notebook desktop](docs/desktop.md) |
| Forgejo, Actions runners, Executor, metrics, and private networking | [Hosted services and Tailnet access](docs/services.md) |
| T3 Code, Claude Code, and Herdr configuration | [AI tools](docs/ai-tools.md) |
| Cache authentication, upload queues, and telemetry | [Shared Nix cache](docs/nix-store-cache.md) |
