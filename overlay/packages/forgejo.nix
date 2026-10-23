{
  callPackage,
  fetchFromGitea,
  lib,
  path,
}: let
  # Reuse nixpkgs' build recipe so the backend and frontend share the fork pin.
  package = import (path + "/pkgs/by-name/fo/forgejo/generic.nix") {
    version = "16.0.3-unstable-2026-10-22";
    rev = "9c0857d037d19f439a149508ee9407e28da0f0f8";
    hash = "sha256-M0RFCxjRtwzhcw8Lh8MCKaNYNBOIULNg9+5vLK4tk+A=";
    npmDepsHash = "sha256-ZIF0udmW1tDzSCsKtZU7S9GMdgfy5fuirtj38nPrnRw=";
    vendorHash = "sha256-eEkZ9I+hlP+QXaLgL5vrkAPiDVvfKEHiNNN6bqYETbM=";
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
