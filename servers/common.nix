{
  pkgs,
  lib,
  ...
}: {
  system.stateVersion = "26.05";

  imports = [
    ../nixos/modules/networking/cloudflare-tunnel.nix
    ../nixos/nix-settings.nix
    ../nixos/registries.nix
    ../nixos/users.nix
    ../nixos/sshHosts.nix
  ];

  environment.systemPackages = with pkgs;
    [
      herdr
      curl
      wget
      git
      jq
      dig
      btop
      ripgrep
      duf
      dua
      cachix
    ]
    ++ lib.optionals (!stdenv.hostPlatform.isAarch64) [
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

  environment.variables.EDITOR = "nvim";

  boot.zfs.forceImportRoot = false;

  programs.neovim = {
    enable = true;
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

  services = {
    machineBackups = {
      directories = [
        {
          name = "machine-identities";
          paths = ["/etc/ssh"];
        }
      ];
      inventory.classifiedRegenerable = [
        {
          path = "/var/lib/systemd/timesync";
          reason = "NTP clock synchronization state is rebuilt from network time; it is not application data.";
        }
      ];
    };
    openssh = {
      enable = lib.mkDefault true;
      ports = [22];
      settings = {
        AllowUsers = ["lotus"];
        PasswordAuthentication = false;
        PermitRootLogin = lib.mkDefault "prohibit-password";
      };
    };
  };
}
