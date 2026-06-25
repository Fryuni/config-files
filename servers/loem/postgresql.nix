{
  config,
  lib,
  ...
}: let
  tailnetHost = "${config.networking.hostName}.${config.services.lferrazTailnetAccess.tailnetDomain}";
in {
  services.postgresql = {
    enable = true;
    settings.listen_addresses = lib.mkForce "localhost,${tailnetHost}";
    authentication = ''
      host all all 127.0.0.1/32 trust
      host all all ::1/128 trust
      host all all 100.64.0.0/10 trust
      host all all fd7a:115c:a1e0::/48 trust
    '';
  };

  systemd.services.postgresql = {
    after = ["tailscaled.service" "tailscaled-autoconnect.service"];
    wants = ["tailscaled.service" "tailscaled-autoconnect.service"];
  };
}
