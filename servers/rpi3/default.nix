{
  config,
  lib,
  pkgs,
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

  # HTTP (incl. CONNECT) and SOCKS5 forward proxy on one port, auto-detected per
  # connection, for apps that should egress from the Pi. Bound only to the
  # Tailscale addresses, which exist only once Tailscale is up.
  systemd.services.tailnet-proxy = {
    description = "HTTP and SOCKS5 proxy on the Tailscale addresses";
    wantedBy = ["multi-user.target"];
    after = ["tailscaled.service"];
    wants = ["tailscaled.service"];
    path = [config.services.tailscale.package];
    serviceConfig = {
      DynamicUser = true;
      Restart = "on-failure";
      # Keep loopback-only services private; LAN and tailnet reach is intended.
      # The resolved stub stays reachable so DNS works.
      IPAddressDeny = "localhost";
      IPAddressAllow = "127.0.0.53";
    };
    script = ''
      tailscale wait
      ips="$(tailscale ip)"
      args=()
      for ip in $ips; do args+=(-L "[$ip]:8888"); done
      # Never start without a bind address.
      (( ''${#args[@]} ))
      exec ${lib.getExe pkgs.gost} "''${args[@]}"
    '';
  };

  services.openssh. settings = {
    KbdInteractiveAuthentication = false;
  };
}
