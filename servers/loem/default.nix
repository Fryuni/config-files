# Hetzner Loem server configuration
{config, ...}: {
  imports = [
    ../common.nix
    ./disko.nix
    ../../nixos/modules/networking/tailscale.nix
    ../../nixos/modules/software-raid.nix
    ../remoteDev.nix
  ];

  age.secrets.tailscale-authkey.rekeyFile = ../../secrets/loem/tailscale-enroll-key;

  services.tailscale.authKeyFile = config.age.secrets.tailscale-authkey.path;

  networking.hostName = "loem";
  hardware.facter.reportPath = ./facter.json;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    devices = ["/dev/sda" "/dev/sdb"];
  };

  # Let this x86_64 server execute common ARM Linux builders through QEMU.
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv6l-linux"
    "armv7l-linux"
  ];

  networking.useDHCP = false;
  networking.interfaces."enp0s31f6" = {
    ipv4.addresses = [
      {
        address = "178.63.139.14";
        prefixLength = 26;
      }
    ];
    ipv6.addresses = [
      {
        address = "2a01:4f8:2240:1605::1";
        prefixLength = 64;
      }
    ];
  };
  networking.defaultGateway = "178.63.139.1";
  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "enp0s31f6";
  };
  networking.nameservers = ["8.8.8.8" "1.1.1.1"];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICphbHvsvJiWjPAV8+JlUZfMHZtXIcp9L+cxn6Y9pjBZ"
  ];
}
