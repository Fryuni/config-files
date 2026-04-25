# Hetzner Loem server configuration
{inputs, ...}: {
  imports = [
    ../common.nix
    ./disko.nix
  ];

  networking.hostName = "loem";
  hardware.facter.reportPath = ./facter.json;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    devices = ["/dev/sda" "/dev/sdb"];
  };

  # boot.initrd.availableKernelModules = [
  #   "xhci_pci"
  #   "ahci"
  #   "sd_mod"
  # ];

  boot.swraid.enable = true;

  # Verify interface name and gateway in Hetzner Robot panel before deploying.
  # Run `ip link` in the rescue system to confirm the interface name.
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

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILI4D6ddYz7WosKUA4Xr7R1cwLF/mpCSWrCSW3O9Ct7E luiz@lferraz.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw luiz@lferraz.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICphbHvsvJiWjPAV8+JlUZfMHZtXIcp9L+cxn6Y9pjBZ"
  ];
}
