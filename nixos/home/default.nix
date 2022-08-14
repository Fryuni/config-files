{ pkgs, ... }:
{
  # Let home-manager manage itself.
  home.stateVersion = "22.05";
  programs.home-manager.enable = true;

  home.username = "lotus";
  home.homeDirectory = "/home/lotus";

  imports = [
    ./git.nix
    ./cli.nix
    ./fonts.nix
    ./terminal.nix
    ./neovim.nix
    ./dev-tools.nix
  ];

  home.packages = with pkgs; [
    flameshot
    sublime4
    discord-canary
  ];

  programs.bash.enable = true;

  programs.ssh.enable = true;
  programs.gpg.enable = true;
  programs.gpg.mutableKeys = true;

  services.gpg-agent.enable = true;
  services.gpg-agent.pinentryFlavor = "tty";

  services.syncthing.enable = true;
}
