{ pkgs, ... }:
{
  imports = [
    ../cli.nix
    ../terminal.nix
    ../wezterm.nix
    ../neovim.nix
    ../dev-tools.nix
  ];
  programs.ssh.enable = true;
  programs.gpg.enable = true;
  programs.gpg.mutableKeys = true;

  services.gpg-agent.enable = true;
  services.gpg-agent.pinentryFlavor = "tty";
}
