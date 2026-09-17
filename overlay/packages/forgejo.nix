{
  callPackage,
  fetchFromGitea,
  lib,
  path,
}: let
  # Reuse nixpkgs' build recipe so the backend and frontend share the fork pin.
  package = import (path + "/pkgs/by-name/fo/forgejo/generic.nix") {
    version = "16.0.3-unstable-2026-09-16";
    rev = "608cbcfa9186b7d4035cb915ef4815f14dfccbc3";
    hash = "sha256-CPVizqdK6Fgqm0BW/hREWK0kA8lLS4PZ4T5rR3nSsq4=";
    npmDepsHash = "sha256-Ceagn54b7ltrWJFvLOFwkQ1K1tP2tjGINErmnAda/kw=";
    vendorHash = "sha256-s2LdqABg7R4GGrCu2yEdKl+PUsM/FnMTFOsDjzJ3JDw=";
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
        updateScript = [./update-forgejo.sh "--no-commit"];
      };
    meta =
      old.meta
      // {
        homepage = "https://git.fryuni.dev/Fryuni/forgejo";
        changelog = "https://git.fryuni.dev/Fryuni/forgejo/commits/branch/forgejo";
        maintainers = [lib.maintainers.fryuni];
      };
  })
