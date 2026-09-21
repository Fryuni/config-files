{
  callPackage,
  fetchFromGitea,
  lib,
  path,
}: let
  # Reuse nixpkgs' build recipe so the backend and frontend share the fork pin.
  package = import (path + "/pkgs/by-name/fo/forgejo/generic.nix") {
    version = "16.0.3-unstable-2026-09-21";
    rev = "7d16ad84f33c0a6a8fd9a903e726587cb8c28647";
    hash = "sha256-CLBUCfelrgLqHPm3g5CB/S/HSY+hUloXfte0gvUQKjg=";
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
