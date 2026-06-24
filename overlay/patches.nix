final: prev: {
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

  # NOTE: Tailscale doesn't support configuring TLS-terminated HTTP services declaratively.
  #   See https://github.com/tailscale/tailscale/issues/18381
  # Use fork with hack fix arround this issue while waiting for official position from Tailscale.
  #   See https://github.com/tailscale/tailscale/issues/18381#issuecomment-4332462281
  tailscale =
    if prev.stdenv.hostPlatform.isAarch64
    then prev.tailscale
    else
      prev.master.tailscale.overrideAttrs (attrs: {
        src = final.fetchFromGitHub {
          owner = "Fryuni";
          repo = "tailscale";
          rev = "7cb26f06c1e9c002907f3ca70a197f4a9dc7ad3e";
          hash = "sha256-czOuezS2JSjTZc5u4O5x39JhstbJDMdeCFsqjkNfYYw=";
        };

        preBuild = ''
          ${attrs.preBuild}

          go mod edit -go=${attrs.passthru.go.version}
        '';

        vendorHash = "sha256-DUWC+1lbebDwAnhsaGOde3mmD3wHEtMdIyYOMhwxpBU=";

        # Reason why it is meaningless also in the issue comment above.
        doCheck = false;
      });
}
