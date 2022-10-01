{ pkgs, ... }:
{
  imports = [
    ./gaming
    ./terminal
    ./development
  ];

  programs.ssh.enable = true;
  programs.gpg.enable = true;
  programs.gpg.mutableKeys = true;

  services.gpg-agent.enable = true;
  services.gpg-agent.pinentryFlavor = "tty";
}
