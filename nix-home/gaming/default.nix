{pkgs, ...}: {
  home.packages = with pkgs; [
    xboxdrv
    prismlauncher
  ];

  programs.obs-studio = {enable = true;};
}
