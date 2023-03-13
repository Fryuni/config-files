{
  pkgs,
  lib,
  ...
}: {
  home.packages = let
    rc = pkgs.rustCrates;
  in
    with pkgs; [
      # Rust tooling
      fenix.complete.toolchain
      rc.cargo-crate
      rc.cargo-watch
      rc.cargo-expand
      rc.cargo-edit
      rc.cargo-sort
      rc.cargo-cache
      rc.bootimage
      rc.cargo-public-api
      # cargo-semver-checks
      # cargo-feature
      # cargo-tauri
      # cargo-clone
      # cargo-bloat
      # cargo-geiger
      # cargo-inspect
      # cargo-deps
      # cargo-wipe
    ];

  home.sessionPath = [
    "$HOME/.cargo/bin"
  ];
}
