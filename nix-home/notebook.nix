{pkgs, ...}: {
  imports = [
    ./ui
    ./gaming
    ./terminal
    ./development
    ./secrets.nix
  ];

  home.username = "lotus";
  home.homeDirectory = "/home/lotus";

  programs.ssh.enable = true;
  programs.gpg.enable = true;
  programs.gpg.mutableKeys = true;

  services.gpg-agent.enable = true;
  services.gpg-agent.pinentry.package = pkgs.pinentry-rofi;
}
