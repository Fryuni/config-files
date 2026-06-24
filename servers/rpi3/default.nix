{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-3
    ../../nixos/modules/networking/tailscale.nix
    ../common.nix
  ];

  # Use the generic cached NixOS aarch64 kernel for target-host updates instead
  # of locally building nixos-hardware's uncached linux-rpi kernel.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  networking.hostName = "rpi3";

  # This host is already installed; build a normal bootable NixOS generation
  # for `nh os boot --target-host rpi3` instead of a full SD-card image.
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };

    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [
        "nofail"
        "noauto"
      ];
    };
  };

  services.vmagent.enable = true;

  # time.timeZone = lib.mkForce "America/Sao_Paulo";
}
