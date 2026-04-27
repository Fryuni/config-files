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
  pgcli = prev.stable.pgcli;

  # Nixpkgs 0726a0e: pkgsi686Linux.openldap fails flaky test017-syncreplication-refresh.
  # Keep native OpenLDAP checks enabled to avoid rebuilding KDE's x86_64 dependency chain.
  openldap = prev.openldap.overrideAttrs (_: {
    doCheck = !prev.stdenv.hostPlatform.isi686;
  });
}
