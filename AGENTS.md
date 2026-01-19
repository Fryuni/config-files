# AGENTS.md - Agent Guidelines for ZShutils

This document provides guidelines for AI coding agents working in this repository.

## Project Overview

**NixOS/Home Manager flake configuration** (dotfiles) managing:
- NixOS system configuration for `lotus-notebook`
- Home Manager user environment
- Custom package overlays and GCE server configurations
- Encrypted secrets via agenix

**Language:** Nix | **Formatter:** alejandra | **Linter:** statix

## Repository Structure

- `flake.nix` / `flake.lock` - Root flake definition and locked dependencies
- `commands.nix` - Flake app commands
- `justfile` - Just command runner recipes
- `nix-home/` - Home Manager modules (development/, terminal/, ui/, gaming/, modules/)
- `nixos/` - NixOS system modules (notebook/, modules/)
- `overlay/` - Nixpkgs overlays (utils.nix, patches.nix, jetbrains/, pulumi/, rustPackages/)
- `servers/` - Server configurations (GCE)
- `secrets/` - Encrypted secrets (agenix)
- `common/` - Shared files (scripts, configs, wallpapers)

## Build/Lint/Test Commands

### Validation (Testing)

No unit tests - validate by building:
```bash
nix run .#build              # Build home config without applying
nix run .#os-build           # Build NixOS config without applying
nix run .#diff               # Show home config changes before applying
nix run .#os-diff            # Show NixOS config changes before applying
```

### Formatting and Linting
```bash
nix fmt .                    # Format all nix files with alejandra
nix fmt <file-path>          # Format specific file
nix run .#fmt                # Run statix fix + alejandra
```

### Dependency Updates
```bash
just update                  # Update flake + overlays + custom packages
just update-flake            # Update flake.lock only
```

### Utility
```bash
nix run .#ls-pkg             # List installed packages
nix-search --flake nixpkgs <term>  # Search for packages
just why-home <pkg>          # Why does home depend on package
```

## Code Style Guidelines

### Naming Conventions
- **Files/directories:** kebab-case (`doom-nvim.nix`, `nix-home/`)
- **Nix attributes:** camelCase (`homeManagerBin`, `pkgsFun`)
- **Package names:** kebab-case (`bitwarden-cli`)

### Module Structure
```nix
{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./submodule.nix
  ];

  home.packages = with pkgs; [
    package1
    package2
  ];

  programs.someProgram = {
    enable = true;
  };
}
```

### Let Bindings
```nix
{pkgs, ...}: let
  someLocal = pkgs.somePackage;
in {
  # module body
}
```

### Overlay Pattern
```nix
final: pkgs: {
  packageName = pkgs.packageName.override { ... };
  newPackage = pkgs.buildGoModule { ... };
}
```

### Imports
```nix
# Module imports: relative paths
imports = [ ./subdir ./file.nix ];

# Overlay imports: use import function
(import ./utils.nix)
```

### Error Handling
```nix
# Throw for unsupported cases
products = versions.${system} or (throw "Unsupported system: ${system}");

# Conditional lists
++ lib.optionals (stdenv.isLinux) [ package1 ]

# Graceful failures in shell commands
${pkgs.someCommand} || true
```

### Secrets (agenix)
```nix
age.secrets.secret-name = {
  file = ../secrets/secret-file;
  path = "/optional/custom/path";
};
```

## Formatting Rules

Run `nix fmt .` before committing. Expectations:
- 2-space indentation
- Trailing semicolons on all attributes
- Opening braces on same line as assignment
- Use `with pkgs;` for package lists

## Commit Style

Use conventional commits with optional scope:
```
type(scope): description
```

**Types:** `feat`, `fix`, `chore`, `wip`

**Scopes** (optional): `cli`, `ide`, `nix`, `os`, `net`, `flake`, `tools`

**Examples:**
- `feat(ide): Install Zed Editor`
- `fix(cli): Downgrade Python used by GCloud SDK`
- `chore: Update flake`
- `chore(cli): Update pulumi`

## Key Dependencies

Access different nixpkgs channels:
- `pkgs` / `final` - Current (unstable)
- `pkgs.stable` / `final.stable` - Stable channel
- `pkgs.master` / `final.master` - Master branch

Key inputs: `nixpkgs`, `home-manager`, `agenix`, `fenix` (Rust), `zig`, `nur`

## Important Notes

1. **Do not apply changes** - Never run `switch` commands; the user will apply changes separately
2. **Do not commit secrets** - Files in `secrets/` are encrypted with agenix
3. **Test builds before applying** - Use `nix run .#build` or `nix run .#os-build`
4. **Use direnv** - The `.envrc` enables nix-direnv for this repo
5. **Target system** - Primary target is `x86_64-linux` (lotus-notebook)
6. **State version** - Current: `26.05` (do not change without migration)
7. **Stage new files for Nix** - Nix flakes only see files that are staged or committed in git. Always run `git add <file>` after creating new files, otherwise Nix commands will not see them
