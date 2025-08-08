{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    ../modules/development.nix
    ../modules/gaming.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  boot.blacklistedKernelModules = ["ideapad_laptop"];
  boot.extraModulePackages = with config.boot.kernelPackages; [zenpower];

  networking.hostName = "lotus-notebook";

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  services.dnscrypt-proxy2.settings.static.NextDNS.stamp = "sdns://AgEAAAAAAAAAAAAOZG5zLm5leHRkbnMuaW8TL2Y3ZmQ1MS9HNS1Ob3RlYm9vaw";

  users.mutableUsers = false;
  users.users.lotus.hashedPassword = "$6$5dd95KPYAytsdzt1$7auK5wgcz3xGilTjmUw./Acr9tNHQDBJn6n9Ob5bgBiL.vXOQQau.5tFhuF0uGkrI.36c8SK61m/P4kBFKoy60";

  nix.settings = {
    cores = 4;
    max-jobs = 4;
  };

  services.fail2ban.enable = true;
  services.openssh = {
    enable = true;
    startWhenNeeded = true;
    ports = [22];
    settings = {
      AllowUsers = ["lotus"];
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      UseDns = true;
      X11Forwarding = false;
      ChallengeResponseAuthentication = "no";
    };
  };

  age.secrets.cloudflared-creds.file = ../../secrets/notebook-cloudflare-tunnel;
  services.cloudflared = {
    enable = true;
    tunnels = {
      "25541cb9-1866-4fd1-a22b-55b12a89f35d" = {
        warp-routing.enabled = true;
        credentialsFile = "${config.age.secrets.cloudflared-creds.path}";
        default = "http_status:404";
        ingress = {
          "notebook.lferraz.dev" = "ssh://localhost:22";
        };
      };
    };
  };

  boot.kernel.sysctl = {
    "net.core.rmem_max" = 7500000;
    "net.core.wmem_max" = 7500000;
  };
}
