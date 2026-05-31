{
  config,
  lib,
  pkgs,
  ...
}: {
  age.secrets.cloudflare-tunnel-token.rekeyFile = ../../secrets/loem/cloudflare-tunnel-token;

  systemd.services.cloudflared-tunnel-loem = {
    description = "Cloudflare Tunnel for loem";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      DynamicUser = true;
      ExecStart = "${lib.getExe pkgs.cloudflared} tunnel --no-autoupdate run --token-file %d/token";
      LoadCredential = ["token:${config.age.secrets.cloudflare-tunnel-token.path}"];
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
