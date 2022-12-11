{nixpkgs ? import <nixpkgs> {}}:
with nixpkgs;
  mkShell {
    packages = with pkgs; [
      gh
    ];
  }
