{pkgs ? import <nixpkgs> {}}:
with pkgs;
  mkShell {
    packages = with pkgs; [
      cargo
      alejandra
      ripgrep
      # cargo-show
      jq
      moreutils
      coreutils
      nix-prefetch
    ];
  }
