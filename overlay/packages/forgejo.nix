{
  callPackage,
  fetchFromGitea,
  lib,
  path,
}: let
  # Reuse nixpkgs' build recipe so the backend and frontend share the fork pin.
  package = import (path + "/pkgs/by-name/fo/forgejo/generic.nix") {
    version = "16.0.3-unstable-2026-10-05";
    rev = "eac3bdaa43693971946d3b6a8487c61ba34ca161";
    hash = "sha256-Rhg8Ow9DhhE0w6oTAv4fvFGRHHh1cJ9yXLe50fMVKzg=";
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
