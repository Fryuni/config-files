{pkgs, ...}: {
  imports = [
    ./gaming
    ./terminal
    ./development
  ];

  home.packages = with pkgs; [
    master.bitwarden-cli
    master.bitwarden-menu
    master.goldwarden
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
