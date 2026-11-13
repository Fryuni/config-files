{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ../common.nix
    ../../nixos/modules/networking/tailscale.nix
    ./zeroclaw.nix
  ];

  networking.hostName = "rpi3";
  system.stateVersion = "26.05";

  # Build natively through binfmt emulation so nearly everything comes from
  # cache.nixos.org; the flake defaults aarch64 boxes to x86_64 cross builds,
  # which have no binary cache. The mainline kernel from the SD image module
  # supports the Pi 3 B and is cached, unlike the nixos-hardware vendor kernel.
  nixpkgs.buildPlatform = lib.mkForce "aarch64-linux";

  # The SD image base profile pulls in many filesystems (including ZFS).
  boot.supportedFilesystems = lib.mkForce ["ext4" "vfat"];
  # Manual pages and the NixOS manual are slow to build under emulation.
  documentation.enable = false;
  # Wired Ethernet needs no firmware; this drops ~800 MiB of linux-firmware.
  hardware.enableRedistributableFirmware = lib.mkForce false;

  # Decrypted with the host key that `just sd-image rpi3` writes into the image.
  age.secrets.tailscale-authkey.rekeyFile = ../../secrets/rpi3/tailscale-enroll-key;
  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-authkey.path;
    fileInbox.enable = false;
    openFirewall = true;
  };
  networking.firewall.trustedInterfaces = [config.services.tailscale.interfaceName];

  services.openssh. settings = {
    KbdInteractiveAuthentication = false;
  };
}
