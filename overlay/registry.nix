# Package registry: the authoritative seam for custom overlay packages.
#
# Each entry is keyed by its public overlay attribute name (or family name for
# specialized families). An entry may declare:
#
#   package - path to the package file exposed by the registry-driven overlay
#             (overlay/packages/default.nix) via callPackage. Entries without
#             `package` are exposed by their own overlay module (utils.nix,
#             patches/, or a specialized family directory).
#
#   update  - automatic update strategy. Omitted for entries that are
#             intentionally not automatically updateable:
#               { kind = "nix-update"; args = [...]; }
#                   invokes nix-update against
#                   legacyPackages.x86_64-linux.<name> with the given extra
#                   arguments. Attribute paths must be fully qualified because
#                   overlay packages are only exposed through legacyPackages
#                   (the full nixpkgs set), which nix-update's flake mode does
#                   not search by default.
#               { kind = "command"; command = "<path>"; }
#                   delegates to a specialized family updater script. The
#                   script owns its algorithm, generated data, staging, and
#                   commit behavior.
#
# The aggregate update command (`just update-overlays`) and single-package
# dispatch (`just update-package <name>` / `overlay/update.sh <name>`) are both
# derived from this file; do not hand-maintain package lists elsewhere.
#
# Adding an ordinary package = drop `<name>.nix` in overlay/packages/ plus one
# entry here. Nothing else.
{
  # --- Ordinary packages: registry-owned exposure + nix-update ---

  cpa-manager-plus = {
    package = ./packages/cpa-manager-plus.nix;
    update = {
      kind = "nix-update";
      args = [];
    };
  };

  openwhispr = {
    package = ./packages/openwhispr.nix;
    update = {
      kind = "nix-update";
      args = [
        "--url"
        "https://github.com/OpenWhispr/openwhispr"
        "--version-regex"
        ''^v?(1\.[0-9]+\.[0-9]+)$''
        "--custom-dep"
        "appImage"
      ];
    };
  };

  # --- Override entries: exposure owned by overlay/patches ---

  # Fork of nixpkgs-master tailscale carrying the declarative TLS-terminated
  # HTTP services hack (nixpkgs#18381) while waiting for an upstream position.
  tailscale.update = {
    kind = "nix-update";
    args = ["--version=branch=main"];
  };

  t-smart-tmux-session-manager.update = {
    kind = "nix-update";
    args = ["--version=branch=main"];
  };

  # --- Specialized families: exposure + updater owned by the family dir ---

  pulumi.update = {
    kind = "command";
    command = "overlay/pulumi/update.sh";
  };

  rustCrates.update = {
    kind = "command";
    command = "overlay/rustPackages/update.mjs";
  };

  # --- Intentionally not automatically updateable ---
  #
  # 1.5.7 is the last MPL-licensed Terraform release; the pin is terminal, so
  # it has no update strategy. Exposure lives in overlay/utils.nix.
  terraformOSS = {};
}
