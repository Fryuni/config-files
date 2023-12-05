homeRoot := ".#homeConfigurations.notebook.activationPackage"
sysRoot := ".#nixosConfigurations.notebook.config.system.build.toplevel"

default:
  nix flake metadata

why-home dependency:
  @nix why-depends --derivation "{{homeRoot}}" ".#{{dependency}}"

why-home-closuje dependency:
  @nix why-depends "{{homeRoot}}" ".#{{dependency}}"

why-sys dependency:
  @nix why-depends --derivation "{{sysRoot}}" ".#{{dependency}}"

why-sys-closuje dependency:
  @nix why-depends "{{sysRoot}}" ".#{{dependency}}"


build-home:
  nix build --no-link --print-out-paths .#homeConfigurations.notebook.activationPackage

build-sys:
  nix build --no-link --print-out-paths .#nixosConfigurations.notebook.config.system.build.toplevel


update: update-flake update-overlays

update-flake-master:
  nix flake lock --update-input nixpkgs-master
  git add flake.lock
  git commit -m "chore: Update flake" -- flake.lock

update-flake:
  nix flake update
  git add flake.lock
  git commit -m "chore: Update flake" -- flake.lock

update-overlays: update-jetbrains update-pulumi

update-jetbrains:
  overlay/jetbrains/update_ides.py

update-pulumi:
  overlay/pulumi/update.sh

