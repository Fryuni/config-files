homeRoot := ".#homeConfigurations.notebook.activationPackage"
sysRoot := ".#nixosConfigurations.notebook.config.system.build.toplevel"

default:
  nix flake metadata

why-home dependency:
  @env NIXPKGS_ALLOW_INSECURE=1 nix why-depends --impure --derivation "{{homeRoot}}" ".#{{dependency}}"

why-home-closure dependency:
  @env NIXPKGS_ALLOW_INSECURE=1 nix why-depends --impure "{{homeRoot}}" ".#{{dependency}}"

why-sys dependency:
  @env NIXPKGS_ALLOW_INSECURE=1 nix why-depends --impure --derivation "{{sysRoot}}" ".#{{dependency}}"

why-sys-closure dependency:
  @env NIXPKGS_ALLOW_INSECURE=1 nix why-depends --impure "{{sysRoot}}" ".#{{dependency}}"

build:
  @nix build --no-link --print-out-paths "{{homeRoot}}"

os-build:
  @nix build --no-link --print-out-paths "{{sysRoot}}"


diff: build
  nix run .#nvd -- diff \
    $(home-manager generations | head -1 | awk '{print $NF}') \
    $(just build)

os-diff: os-build
  nix run .#nvd -- diff /run/current-system $(just os-build)

switch:
  nix run .#switch

os-boot:
  nix run .#os-boot


update: update-flake update-overlays

update-flake-master:
  nix flake lock --update-input nixpkgs-master
  git add flake.lock
  git commit -m "chore: Update flake" -- flake.lock

update-flake:
  nix flake update
  git add flake.lock
  git commit -m "chore: Update flake" -- flake.lock

update-overlays: update-pulumi update-rustCrates

update-jetbrains:
  overlay/jetbrains/update_ides.py

update-pulumi:
  overlay/pulumi/update.sh

update-rustCrates:
  overlay/rustPackages/update.sh

