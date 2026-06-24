{
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs) stdenv;
in {
  system.stateVersion = "26.05";

  imports = [
    ../nixos/modules/networking/cloudflare-tunnel.nix
    ../nixos/nix-settings.nix
    ../nixos/registries.nix
  ];

  environment.systemPackages = with pkgs;
    [
      tmux
      curl
      wget
      git
      jq
      dig
      htop
      btop
      gnumake
      ripgrep
      duf
      dua
    ]
    ++ lib.optionals (!stdenv.hostPlatform.isAarch64) [
      gcc
      clang
      xarchiver
      cachix
      (google-cloud-sdk.withExtraComponents (
        with google-cloud-sdk.components; [
          docker-credential-gcr
          beta
          alpha
          gsutil
          gke-gcloud-auth-plugin
          # terraform-tools
        ]
      ))
    ];

  environment.variables.EDITOR =
    if stdenv.hostPlatform.isAarch64
    then "nano"
    else "nvim";

  boot.zfs.forceImportRoot = false;

  programs.neovim = {
    enable = !stdenv.hostPlatform.isAarch64;
  };

  time.timeZone = "UTC";

  security.sudo.wheelNeedsPassword = false;

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = lib.mkDefault "prohibit-password";
    };
  };
}
