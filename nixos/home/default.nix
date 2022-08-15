{ pkgs, ... }:
{
  # Let home-manager manage itself.
  home.stateVersion = "22.05";
  programs.home-manager.enable = true;

  # https://github.com/nix-community/home-manager/issues/2942
  nixpkgs.config.allowUnfreePredicate = (pkg: true);

  home.username = "lotus";
  home.homeDirectory = "/home/lotus";

  imports = [
    ./app
    ./git.nix
    ./cli.nix
    ./fonts.nix
    ./terminal.nix
    ./neovim.nix
    ./dev-tools.nix

    # Missing configuration regarding i3 windowManager. Inspiration reference:
    # https://github.com/tars0x9752/home/blob/main/modules/rice.nix
  ];

  programs.ssh.enable = true;
  programs.gpg.enable = true;
  programs.gpg.mutableKeys = true;

  services.gpg-agent.enable = true;
  services.gpg-agent.pinentryFlavor = "tty";

  services.syncthing.enable = true;
}
