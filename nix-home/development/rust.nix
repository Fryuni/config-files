{
  pkgs,
  lib,
  ...
}: {
  home.packages = let
    rc = pkgs.rustCrates;
  in
    with pkgs; [
      ## Rust tooling
      (fenix.combine [
        fenix.complete.toolchain
        fenix.targets.wasm32-unknown-unknown.latest.rust-std
      ])
      # rc.cargo-lock
      # rc.cargo-expand
      # rc.cargo-deps

      ## Plumbing tools
      # rc.cargo-crate
      # rc.cargo-cache
      stable.cargo-geiger

      ## DX
      # rc.cargo-docs
      cargo-edit
      cargo-watch
      # rc.cargo-sort
      # rc.cargo-public-api
      # rc.cargo-semver-checks

      # Blog OS project
      # rc.bootimage

      # cargo-feature
      # cargo-tauri
      # cargo-clone
      # cargo-bloat
      # cargo-inspect
      # cargo-wipe
    ];

  home.sessionPath = [
    "$HOME/.cargo/bin"
  ];
}
