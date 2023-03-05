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
      cargo-expand
      cargo-edit
      cargo-sort
      cargo-cache
      cargo-bootimage
      # cargo-public-api
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
