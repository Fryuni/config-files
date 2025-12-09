{pkgs, ...}: {
  system.stateVersion = "26.05";

  imports = [
    ../nixos/nix-settings.nix
    ../nixos/registries.nix
    ../nixos/users.nix
  ];

  environment.systemPackages = with pkgs; [
    curl
    wget
    git
    dig
    btop
    gnumake
    xarchiver
    cachix
  ];

  programs.neovim = {
    enable = true;
  };

  time.timeZone = "UTC";

  i18n.defaultLocale = "en_US.utf8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.utf8";
    LC_IDENTIFICATION = "en_US.utf8";
    LC_MEASUREMENT = "en_US.utf8";
    LC_MONETARY = "en_US.utf8";
    LC_NAME = "en_US.utf8";
    LC_NUMERIC = "en_US.utf8";
    LC_PAPER = "en_US.utf8";
    LC_TELEPHONE = "en_US.utf8";
    LC_TIME = "en_US.utf8";
  };
}
