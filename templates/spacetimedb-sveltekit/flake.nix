{
  description = "SpacetimeDB TypeScript and SvelteKit development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"] (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) ["spacetimedb"];
      };
    in {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs_24
          pnpm
          spacetimedb
        ];
      };
    });
}
