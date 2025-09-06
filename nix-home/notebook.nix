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

  home.packages = with pkgs; [
    master.bitwarden-desktop
    master.bitwarden-cli
  ];

  programs.gpg.enable = true;
  programs.gpg.mutableKeys = true;
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };

  services.gpg-agent.enable = true;
  services.gpg-agent.pinentry.package = pkgs.pinentry-rofi;
}
