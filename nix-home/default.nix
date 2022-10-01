{ pkgs, ... }:
{
  # Let home-manager manage itself.
  home.stateVersion = "22.05";
  programs.home-manager.enable = true;

  # https://github.com/nix-community/home-manager/issues/2942
  nixpkgs.config.allowUnfreePredicate = pkg: true;

  home.username = "lotus";
  home.homeDirectory = "/home/lotus";

  imports = [
    ./ui
  ];

  services.syncthing.enable = true;
}
