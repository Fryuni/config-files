{pkgs, ...}: {
  home.packages = with pkgs; [
    xboxdrv
    polymc
  ];

  programs.obs-studio = {enable = true;};
}
