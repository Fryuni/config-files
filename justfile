homeRoot := ".#homeConfigurations.lotus@lotus-notebook.activationPackage"
sysRoot := ".#nixosConfigurations.lotus-notebook.config.system.build.toplevel"

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

build-sd-image config:
  nix build --impure --no-link --print-out-paths ".#nixosConfigurations.{{config}}.config.system.build.sdImage"

flash-sd-image config device:
  #!/usr/bin/env bash
  set -euo pipefail
  image_path=$(nix build --impure --no-link --print-out-paths ".#nixosConfigurations.{{config}}.config.system.build.sdImage")
  image_file=$(find "$image_path" -name '*.img.zst' | head -1)
  echo "Flashing $image_file to {{device}}"
  zstdcat "$image_file" | sudo dd of={{device}} bs=4M status=progress conv=fsync

deploy config host="":
  #!/usr/bin/env bash
  DEPLOY_HOST="{{host}}"
  : ${DEPLOY_HOST:="{{config}}"}
  nixos-rebuild switch --flake ".#{{config}}" --target-host "$DEPLOY_HOST" --use-substitutes --sudo

deploy-reboot config host="":
  #!/usr/bin/env bash
  DEPLOY_HOST="{{host}}"
  : ${DEPLOY_HOST:="{{config}}"}
  nixos-rebuild boot --flake ".#{{config}}" --target-host "$DEPLOY_HOST" --use-substitutes --sudo
  ssh "$DEPLOY_HOST" "sudo systemctl reboot"

remote-switch config host="":
  #!/usr/bin/env bash
  DEPLOY_HOST="{{host}}"
  : ${DEPLOY_HOST:="{{config}}"}
  ssh "$DEPLOY_HOST" "sudo nixos-rebuild switch --flake gitlab:Fryuni/ZShtuils#{{config}}"

hostkey config host:
  #!/usr/bin/env bash
  set -euo pipefail

  mkdir -p secrets/host-keys
  target="secrets/host-keys/{{config}}.pub"
  tmp="$(mktemp)"
  scan="$(mktemp)"
  trap 'rm -f "$tmp" "$scan"' EXIT
  ssh-keyscan -t ed25519 "{{host}}" > "$scan" || true
  awk -v host="{{host}}" '
    $2 == "ssh-ed25519" { keys[$2 " " $3] = 1 }
    END {
      for (key in keys) { line = key; count++ }
      if (count == 0) {
        print "No ed25519 host key found for " host > "/dev/stderr"
        exit 1
      }
      if (count > 1) {
        print "Multiple distinct ed25519 host keys found for " host > "/dev/stderr"
        exit 1
      }
      print line
    }
  ' "$scan" > "$tmp"
  mv "$tmp" "$target"
  trap - EXIT
  git add "$target"
  printf '%s\n' "$target"

rekey *args:
  #!/usr/bin/env bash
  set -euo pipefail

  system="$(nix eval --raw --impure --expr builtins.currentSystem)"
  nix run ".#agenix-rekey.${system}.rekey" -- {{args}}
