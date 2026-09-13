{
  callPackage,
  fetchFromGitea,
  lib,
  path,
}: let
  # Reuse nixpkgs' build recipe so the backend and frontend share the fork pin.
  package = import (path + "/pkgs/by-name/fo/forgejo/generic.nix") {
    version = "16.0.3-unstable-2026-09-13";
    rev = "e7b6fafc0eb7c8ed5e65a45f8f641a117ffa7dcc";
    hash = "sha256-MehgVv9kRlhsmmOfagnoUhNeOY0moGMnR1eK4Lt8dXg=";
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
