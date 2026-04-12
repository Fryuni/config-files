# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NixOS/Home Manager flake configuration (dotfiles) for user `lotus` on `lotus-notebook` (x86_64-linux). Manages system configuration, user environment, custom package overlays, and encrypted secrets via agenix.

**Language:** Nix | **Formatter:** alejandra | **Linter:** statix

## Build and Validation Commands

There are no unit tests. Validate by building:

```bash
nix run .#build              # Build home config without applying
nix run .#os-build           # Build NixOS config without applying
nix run .#diff               # Show home config changes before applying
nix run .#os-diff            # Show NixOS config changes before applying
```

### Formatting and Linting

```bash
nix fmt .                    # Format all nix files with alejandra
nix run .#fmt                # Run statix fix + alejandra (preferred)
```

Always run `nix fmt .` before committing.

### Dependency Updates

```bash
just update                  # Update flake + overlays + custom packages
just update-flake            # Update flake.lock only
```

### Utility

```bash
nix run .#ls-pkg             # List installed packages
just why-home <pkg>          # Why does home depend on package
just why-sys <pkg>           # Why does system depend on package
```

## Architecture

The flake defines three nixpkgs channels accessible as `pkgs`/`pkgs.stable`/`pkgs.master` (unstable, stable, master). Overlays in `overlay/default.nix` compose external flake overlays with local ones.

**Home Manager** (`nix-home/`): The entry point is `default.nix` (shared) + `notebook.nix` (machine-specific). Modules are organized by domain: `development/` (git, IDEs, rust, tools), `terminal/` (shell, editors, terminal emulators, AI), `ui/` (Hyprland, Plasma, GTK, Rofi), `gaming/`, `modules/` (custom HM modules like node-red).

**NixOS** (`nixos/`): System-level config. `default.nix` is shared across machines, `notebook/` is machine-specific. Includes networking, audio, Hyprland, and user management.

**Overlays** (`overlay/`): Custom packages and patches. Each file/directory is a self-contained overlay. Update scripts exist for jetbrains, pulumi, and rustPackages.

**Servers** (`servers/`): GCE server configurations.

**Secrets** (`secrets/`): agenix-encrypted files. `secrets.nix` defines which keys can decrypt each secret.

## Code Conventions

### Naming
- Files/directories: kebab-case (`doom-nvim.nix`, `nix-home/`)
- Nix attributes: camelCase (`homeManagerBin`, `pkgsFun`)
- Package names: kebab-case (`bitwarden-cli`)

### Formatting (enforced by alejandra)
- 2-space indentation
- Trailing semicolons on all attributes
- Opening braces on same line as assignment
- Use `with pkgs;` for package lists

### Commit Style

Conventional commits: `type(scope): description`

Types: `feat`, `fix`, `chore`, `wip`
Scopes (optional): `cli`, `ide`, `nix`, `os`, `net`, `flake`, `tools`, `term`, `ai`

## Critical Rules

1. **Never run `switch` commands** — the user applies changes separately
2. **Never commit files in `secrets/`** — they are agenix-encrypted
3. **Stage new files for Nix** — Nix flakes only see git-tracked files. Run `git add <file>` after creating new files
4. **State version is `26.05`** — do not change without migration
5. **Target system** — primary target is `x86_64-linux`
