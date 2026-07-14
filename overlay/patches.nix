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
  tailscale = prev.master.tailscale.overrideAttrs (attrs: {
    src = final.fetchFromGitHub {
      owner = "Fryuni";
      repo = "tailscale";
      rev = "d3b0435cb1da6f800a62b65ce7788b0aafe669a5";
      hash = "sha256-XEPI5NuXl9ojVmIo34CQDiGVn62440TCO+E/SjN6p74=";
    };

    preBuild = ''
      ${attrs.preBuild}

      go mod edit -go=${attrs.passthru.go.version}
    '';

    vendorHash = "sha256-y6rBPJtkhTQMsnUoUC/1Up61FEplPpxaU1OkO2FDeio=";

    # Reason why it is meaningless also in the issue comment above.
    doCkeck = false;
  });
}
