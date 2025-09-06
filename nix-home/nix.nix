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

  home.packages = with pkgs; [fh];

  programs.nh.enable = true;

  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };

  nix = {
    # package = pkgs.nix;

    settings.nix-path = [
      "fryuni=${inputs.self}"
      "nixpkgs=${inputs.nixpkgs}"
      "nixpkgs-stable=${inputs.nixpkgs-stable}"
      "nixpkgs-master=${inputs.nixpkgs-master}"
      "/nix/var/nix/profiles/per-user/root/channels"
    ];

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
