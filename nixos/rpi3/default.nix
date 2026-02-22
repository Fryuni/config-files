{
  config,
  pkgs,
  modulesPath,
  inputs,
  ...
}: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    inputs.nixos-hardware.nixosModules.raspberry-pi-3
    ../modules/networking/tailscale.nix
    ../nix-settings.nix
    ../registries.nix
    ../users.nix
  ];

  networking.hostName = "rpi3";

  time.timeZone = "America/Sao_Paulo";

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.lotus = {
    isNormalUser = true;
    description = "Void Lotus";
    extraGroups = ["wheel"];
  };

  security.sudo.wheelNeedsPassword = false;

  networking.firewall.allowedTCPPorts = [22];
  services.openssh = {
    enable = true;
    ports = [22];
    settings = {
      AllowUsers = ["lotus"];
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.lotus = {
      home.username = "lotus";
      home.homeDirectory = "/home/lotus";
      home.stateVersion = "26.05";
    };
  };

  environment.systemPackages = with pkgs; [
    curl
    wget
    git
    htop
    nh
  ];

  nix.settings = {
    trusted-users = ["root" "lotus"];
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  system.stateVersion = "26.05";
}
