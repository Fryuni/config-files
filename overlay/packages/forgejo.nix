{
  callPackage,
  fetchFromGitea,
  lib,
  path,
}: let
  # Reuse nixpkgs' build recipe so the backend and frontend share the fork pin.
  package = import (path + "/pkgs/by-name/fo/forgejo/generic.nix") {
    version = "16.0.3-unstable-2026-11-04";
    rev = "3d64256c884b62d29718f909e23ebec3493a6c9f";
    hash = "sha256-fER7NsJGH7NFp6qBRqpdKEXa3LXTD0dIB7hYJd80M50=";
    npmDepsHash = "sha256-uTi1c4PnvhKLxL/A+TI0t6bLmRw0Qo7b67+tCeVZqu8=";
    vendorHash = "sha256-8S1LmnPmj/lvg54BkYC58Pu3K28kAjZY1+8fg+BYFfM=";
  };
in
  (callPackage package {
    fetchFromCodeberg = args:
      fetchFromGitea (args
        // {
          domain = "git.fryuni.dev";
          owner = "Fryuni";
        });
  }).overrideAttrs (old: {
    # This branch adds a test that makes real HTTP requests to example.com.
    checkFlags = map (flag: flag + "|^TestActivityPubMatchesList$") old.checkFlags;
    doCheck = false;
    passthru =
      old.passthru
      // {
        updateScript = [../update-fork.sh "forgejo" "forgejo" "overlay/packages/forgejo.nix" "--no-commit"];
      };
    meta =
      old.meta
      // {
        homepage = "https://git.fryuni.dev/Fryuni/forgejo";
        changelog = "https://git.fryuni.dev/Fryuni/forgejo/commits/branch/forgejo";
        maintainers = [lib.maintainers.fryuni];
      };
  })
