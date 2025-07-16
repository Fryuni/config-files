{pkgs, ...}: {
  home.packages = with pkgs; [
    # prismlauncher
    parsec-bin
  ];

  programs.obs-studio = {enable = true;};
}
