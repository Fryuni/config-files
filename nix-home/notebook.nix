{pkgs, ...}: {
  imports = [
    ./gaming
    ./terminal
    ./development
  ];

  home.packages = with pkgs; [
    master.bitwarden-desktop
    master.bitwarden-cli
    master.bitwarden-menu
    master.goldwarden
  ];

  programs.ssh.enable = true;
  programs.gpg.enable = true;
  programs.gpg.mutableKeys = true;

  services.gpg-agent.enable = true;
  services.gpg-agent.pinentry.package = pkgs.pinentry-rofi;
}
