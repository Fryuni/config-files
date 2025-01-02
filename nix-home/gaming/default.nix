{pkgs, ...}: {
  home.packages = with pkgs; [
    prismlauncher
  ];

  programs.obs-studio = {enable = true;};
}
