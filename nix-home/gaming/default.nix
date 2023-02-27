{pkgs, ...}: {
  home.packages = with pkgs; [
    # polymc
  ];

  programs.obs-studio = {enable = true;};
}
