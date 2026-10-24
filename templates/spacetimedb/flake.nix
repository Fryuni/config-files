{
  description = "SpacetimeDB Rust module development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    flake-utils,
    fenix,
    ...
  }:
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"] (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) ["spacetimedb"];
      };
      rustToolchain = with fenix.packages.${system};
        combine [
          complete.toolchain
          targets.wasm32-unknown-unknown.latest.rust-std
        ];
    in {
      devShells.default = pkgs.mkShell {
        packages = [
          rustToolchain
          pkgs.spacetimedb
        ];
      };
    });
}
