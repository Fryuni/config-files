homeRoot := ".#homeConfigurations.notebook.activationPackage"
sysRoot := ".#nixosConfigurations.notebook.config.system.build.toplevel"

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

build *args:
  @nix build --no-link --print-out-paths "{{homeRoot}}" {{args}}

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

## Raspberry Pi

# Build a Raspberry Pi image and burn it into an SD card
burn-rpi-image node device:
  #!/usr/bin/env bash
  set -euxo pipefail
  BUILT_IMAGE_STORE_PATH="$(nix build --no-link --print-out-paths .#nixosConfigurations.{{node}}.config.system.build.sdImage)"
  IMAGE_PATH="${BUILT_IMAGE_STORE_PATH}/sd-image/nixos-rpi.img"

  sudo dd status=progress if="$IMAGE_PATH" of="{{device}}"

run-rpi-image node:
  qemu-system-aarch64 \
    -machine raspi3b \
    -cpu cortex-a72 \
    -smp 4 -m 1G \
    -dtb treeblob.dtb \
    -drive "file=$(nix build --no-link --print-out-paths .#nixosConfigurations.{{node}}.config.system.build.sdImage)/sd-image/nixos-rpi.img,format=raw,index=0,if=sd" \
    -device usb-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp::50022-:22 \
    -monitor tcp:127.0.0.1:50021,server,nowait \
    -nographic
