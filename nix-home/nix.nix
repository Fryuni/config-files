{
  inputs,
  pkgs,
  ...
}: {
  xdg.configFile."nixpkgs/config.nix".text = ''
    {
      allowUnfree = true;
    }
  '';

  nix = {
    package = pkgs.nix;

    registry = {
      # Register this flake itself on the registry
      me.flake = inputs.self;

      nixpkgs.flake = inputs.nixpkgs;
      nixpkgs-stable.flake = inputs.nixpkgs-stable;
      nixpkgs-master.flake = inputs.nixpkgs-master;
      home-manager.flake = inputs.home-manager;
      flake-utils.flake = inputs.flake-utils;

      # node.to = {
      #   type = "github";
      #   owner = "andyrichardson";
      #   repo = "nix-node";
      # };
    };
  };
}
