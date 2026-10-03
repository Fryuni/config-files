{
  callPackage,
  fetchFromGitea,
  lib,
  path,
}: let
  # Reuse nixpkgs' build recipe so the backend and frontend share the fork pin.
  package = import (path + "/pkgs/by-name/fo/forgejo/generic.nix") {
    version = "16.0.3-unstable-2026-09-30";
    rev = "2f05597868342890dbeee1d51f34f380c128d322";
    hash = "sha256-cx97apXJnuXpJpR0cg3eTXGE2zSRG4qF1ffvnpKASlU=";
    npmDepsHash = "sha256-il9d0L9JxYi1oj8cHa7mSuwKuCM9nRoVJU68Ro5RLWU=";
    vendorHash = "sha256-fvYYOdktQbVM4GDKxz7b5Y8MlXtzE+0dMkbOsbiGOxw=";
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
