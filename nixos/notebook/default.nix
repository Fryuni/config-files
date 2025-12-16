{
  config,
  pkgs,
  lib,
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
  networking.nameservers = lib.mkForce [
    "45.90.28.0#G5--Note-f7fd51.dns.nextdns.io"
    "2a07:a8c0::#G5--Note-f7fd51.dns.nextdns.io"
    "45.90.30.0#G5--Note-f7fd51.dns.nextdns.io"
    "2a07:a8c1::#G5--Note-f7fd51.dns.nextdns.io"
  ];
  services.resolved.domains = lib.mkForce [
    "45.90.28.0#G5--Note-f7fd51.dns.nextdns.io"
    "2a07:a8c0::#G5--Note-f7fd51.dns.nextdns.io"
    "45.90.30.0#G5--Note-f7fd51.dns.nextdns.io"
    "2a07:a8c1::#G5--Note-f7fd51.dns.nextdns.io"
  ];

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  users.mutableUsers = false;
  users.users.lotus.hashedPassword = "$6$5dd95KPYAytsdzt1$7auK5wgcz3xGilTjmUw./Acr9tNHQDBJn6n9Ob5bgBiL.vXOQQau.5tFhuF0uGkrI.36c8SK61m/P4kBFKoy60";

  users.users.lotus.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILI4D6ddYz7WosKUA4Xr7R1cwLF/mpCSWrCSW3O9Ct7E luiz@lferraz.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw luiz@lferraz.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICphbHvsvJiWjPAV8+JlUZfMHZtXIcp9L+cxn6Y9pjBZ"
  ];

  nix.settings = {
    cores = 4;
    max-jobs = 4;
  };

  services.openssh = {
    enable = true;
    startWhenNeeded = true;
    ports = [22];
    settings = {
      AllowUsers = ["lotus"];
      PermitRootLogin = "no";
      PasswordAuthentication = false;
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
