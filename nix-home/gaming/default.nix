{pkgs, ...}: {
  home.packages = with pkgs; [
    prismlauncher
    parsecgaming
  ];

  programs.obs-studio = {enable = true;};
}
