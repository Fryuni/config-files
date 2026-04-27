{
  config,
  pkgs,
  lib,
  modulesPath,
  inputs,
  ...
}: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    inputs.nixos-hardware.nixosModules.raspberry-pi-3
    ../../nixos/modules/networking/tailscale.nix
    ../common.nix
    ../interactive.nix
  ];

  networking.hostName = "rpi3";

  services.vmagent.enable = true;

  # time.timeZone = lib.mkForce "America/Sao_Paulo";
}
