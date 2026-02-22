homeRoot := ".#homeConfigurations.lotus@lotus-notebook.activationPackage"
sysRoot := ".#nixosConfigurations.lotus-notebook.config.system.build.toplevel"
rpi3Image := ".#nixosConfigurations.lotus-rpi3.config.system.build.sdImage"

default:
  nix flake metadata

why-home dependency *args:
  @env NIXPKGS_ALLOW_INSECURE=1 nix why-depends --impure --derivation "{{homeRoot}}" ".#{{dependency}}" {{args}}

why-home-closure dependency *args:
  @env NIXPKGS_ALLOW_INSECURE=1 nix why-depends --impure "{{homeRoot}}" ".#{{dependency}}" {{args}}

why-sys dependency *args:
  @env NIXPKGS_ALLOW_INSECURE=1 nix why-depends --impure --derivation "{{sysRoot}}" ".#{{dependency}}" {{args}}

why-sys-closure dependency *args:
  @env NIXPKGS_ALLOW_INSECURE=1 nix why-depends --impure "{{sysRoot}}" ".#{{dependency}}" {{args}}

tree-home:
  nix-tree --derivation "{{homeRoot}}"

tree-sys:
  nix-tree --derivation "{{sysRoot}}"

update: update-flake update-overlays

update-flake-master:
  nix flake update nixpkgs-master
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
  overlay/rustPackages/update.mjs

apply-reload:
  home-manager switch --flake .
  sudo nixos-rebuild switch --flake .
  systemctl reboot

build-rpi3-image:
  nix build --impure --no-link --print-out-paths "{{rpi3Image}}"
