{ pkgs, libs, home-manager, ... }:
{
  environment.variables.EDITOR = "nvim";

  imports = [
    home-manager.nixosModules.home-manager
    ./home-manager.nix
  ];


  documentation.dev.enable = true;
}
