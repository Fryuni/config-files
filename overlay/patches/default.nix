_: prev: {
  # Determinate Nix 3.23 adds activity 10113 and result 10111 to internal-json.
  # Remove once nixpkgs carries https://github.com/maralorn/nix-output-monitor/pull/321.
  nix-output-monitor = assert prev.lib.assertMsg (prev.nix-output-monitor.version == "2.2.0")
  "nix-output-monitor changed from 2.2.0 to ${prev.nix-output-monitor.version}; review whether the unknown activity/result types patch is still needed.";
    prev.nix-output-monitor.override {
      extraComposeFunctions = [
        (prev.haskell.lib.compose.appendPatch ./nix-output-monitor-unknown-types.patch)
      ];
    };

  python312Packages =
    prev.python312Packages
    // {
      patool = prev.python312Packages.patool.overrideAttrs (_: _: {
        doCheck = false;
        doInstallCheck = false;
      });
    };

  # Nixpkgs 0726a0e: python313Packages.cli-helpers 2.10.0 fails its Pygments style tests.
  # Use stable pgcli until the cli-helpers 2.14.0 update reaches this input.
  inherit (prev.stable) pgcli;

  # Nixpkgs 0726a0e: pkgsi686Linux.openldap fails flaky test017-syncreplication-refresh.
  # Keep native OpenLDAP checks enabled to avoid rebuilding KDE's x86_64 dependency chain.
  openldap = prev.openldap.overrideAttrs (_: {
    doCheck = !prev.stdenv.hostPlatform.isi686;
  });

  git-sync = prev.git-sync.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./git-sync-debounce.patch];
  });

  # SNI pixmaps are four-byte ARGB pixels; the upstream stride corrupts icons.
  snixembed = prev.snixembed.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./snixembed-pixel-stride.patch];
  });

  t-smart-tmux-session-manager = prev.tmuxPlugins.t-smart-tmux-session-manager.overrideAttrs (_: {
    version = "0-unstable-2026-05-22";
    src = prev.fetchgit {
      url = "https://codeberg.org/Fryuni/t-smart-tmux-session-manager.git";
      rev = "ad54e819c99d1a1cc460bd46352bcfb3f02270ed";
      hash = "sha256-qDPihXpDga8SAp+uuIwUu4au9CwJy/OFJnK50QobTuw=";
    };
  });
}
