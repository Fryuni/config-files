{config, ...}: {
  imports = [
    ../../nixos/modules/networking/tailscale.nix
  ];

  networking.hostName = "loem";
  age.secrets.tailscale-authkey.rekeyFile = ../../secrets/loem/tailscale-enroll-key;
  services.tailscale.authKeyFile = config.age.secrets.tailscale-authkey.path;

  networking.firewall.enable = false;
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

  services.cfTunnel = {
    tunnel-id = "76fe45e2-d197-49bf-aaf2-e6b3dc2dd2f6";
    token-secret = ../../secrets/loem/cloudflare-tunnel-token;
  };
}
