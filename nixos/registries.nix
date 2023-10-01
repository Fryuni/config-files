{inputs, ...}: {
  nix.nixPath = [
    "fryuni=${inputs.self}"
    "nixpkgs=${inputs.nixpkgs}"
    "nixpkgs-stable=${inputs.nixpkgs-stable}"
    "nixpkgs-master=${inputs.nixpkgs-master}"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];

  # systemd.tmpfiles.rules = [
  # "L+ ${nixpkgsPath}       - - - - ${inputs.nixpkgs}"
  # "L+ ${nixpkgsStablePath} - - - - ${inputs.nixpkgs-stable}"
  # "L+ ${devshellPath}      - - - - ${inputs.devshell}"
  # ];

  nix.registry = {
    # Register this flake itself on the registry
    me.flake = inputs.self;

    nixpkgs.flake = inputs.nixpkgs;
    nixpkgs-stable.flake = inputs.nixpkgs-stable;
    nixpkgs-master.flake = inputs.nixpkgs-master;
    home-manager.flake = inputs.home-manager;
    flake-utils.flake = inputs.flake-utils;
    # devshell.flake = inputs.devshell;

    # node.to = {
    #   type = "github";
    #   owner = "andyrichardson";
    #   repo = "nix-node";
    # };
  };
}
