{
  callPackage,
  fetchFromGitea,
  lib,
  path,
}: let
  # Reuse nixpkgs' build recipe so the backend and frontend share the fork pin.
  package = import (path + "/pkgs/by-name/fo/forgejo/generic.nix") {
    version = "16.0.3-unstable-2026-09-10";
    rev = "8c08f92175d78bdb970d012eef3faae4dd5bed0d";
    hash = "sha256-WOHyGA0qjXL/uGWedr1+8W6eK8I9HJMNo9HjMHRjcuU=";
    npmDepsHash = "sha256-1U2pKllliQSDTTdb5lECQC30kAI9Re78TcUZE1vgYsU=";
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
