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
  ];

  networking.hostName = "rpi3";

  # Build the Pi image as an x86_64 -> aarch64 cross system on the notebook.
  # Without an explicit buildPlatform, pure flake evaluation treats this as a
  # native aarch64 build and runs timing-sensitive target tests under emulation
  # (coreutils 9.10 env-signal-handler is one such flaky test).
  nixpkgs.buildPlatform = lib.mkDefault "x86_64-linux";
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  services.vmagent.enable = true;

  # time.timeZone = lib.mkForce "America/Sao_Paulo";
}
