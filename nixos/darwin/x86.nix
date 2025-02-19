{pkgs, ...}: {
  imports = [
    ./homebrew.nix
    ../nix-settings.nix
    ../registries.nix
  ];

  system.stateVersion = 5;

  nixpkgs.hostPlatform = "x86_64-darwin";
  networking.localHostName = "Fry-MacBook-x86";

  programs.zsh.enable = true;
  users.users.lotus = {
    uid = 401;
    description = "Void Lotus";
    isHidden = false;
    createHome = true;
    home = "/Users/lotus";
    shell = pkgs.zsh;
  };

  nix.settings = {
    trusted-users = ["root" "lotus" "@admin"];
  };

  programs.direnv = {
    enable = true;
    silent = true;
    nix-direnv.enable = true;
  };
}
