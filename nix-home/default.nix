{pkgs, ...}: {
  # Let home-manager manage itself.
  home.stateVersion = "22.05";
  programs.home-manager.enable = true;

  home.username = "lotus";
  home.homeDirectory = "/home/lotus";

  imports = [
    ./ui
  ];

  services.syncthing.enable = true;
}
