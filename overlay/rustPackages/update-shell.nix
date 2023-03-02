{pkgs ? import <nixpkgs> {}}:
with pkgs;
  mkShell {
    packages = with pkgs; [
      cargo
      alejandra
      ripgrep
      rustCrates.cargo-crate
      jq
      moreutils
      coreutils
      nix-prefetch
    ];
  }
