{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
  ];

  environment.systemPackages = with pkgs; [libraspberrypi];

  hardware.enableRedistributableFirmware = true;
  # networking.wireless.enable = true;

  system.stateVersion = "24.11";
  sdImage.compressImage = false;
  image.baseName = "nixos-rpi";

  # Preserve space by sacrificing documentation and history
  documentation.nixos.enable = false;
  boot.tmp.cleanOnBoot = true;

  # Configure basic SSH access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw luiz@lferraz.com"
    ];
  };

  # Use 1GB of additional swap memory in order to not run out of memory
  # when installing lots of things while running other things at the same time.
  swapDevices = [
    {
      device = "/swapfile";
      size = 1024;
    }
  ];
}
