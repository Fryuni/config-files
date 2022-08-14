{ config, pkgs, ... }:
{
  imports = [
    ./nvidia.nix
    ../modules/development.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  boot.extraModulePackages = with config.boot.kernelPackages; [ zenpower ];

  networking.hostName = "lotus-notebook";

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
}
