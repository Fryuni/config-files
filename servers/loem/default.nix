# Hetzner Loem server configuration
{...}: {
  imports = [
    ../../nixos/modules/docker.nix
    ../../nixos/modules/software-raid.nix

    ../common.nix
    ../remoteDev.nix

    ./disko.nix
    ./forgejo.nix
    ./matrix.nix
    ./metrics
    ./networking.nix
    ./soft-serve.nix
  ];

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

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICphbHvsvJiWjPAV8+JlUZfMHZtXIcp9L+cxn6Y9pjBZ"
  ];

  nix = {
    distributedBuilds = true;
    settings = {
      cores = 3;
      max-jobs = 2;
    };
  };

  home-manager.users.lotus.hermes.enabled = true;
}
