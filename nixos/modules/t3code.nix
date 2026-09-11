{pkgs, ...}: let
  port = 3773;
in {
  systemd.services.t3code = {
    description = "T3 Code server";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];

    # Reuse lotus's provider credentials and development tools without a login session.
    environment = {
      HOME = "/home/lotus";
      T3CODE_TELEMETRY_ENABLED = "false";
    };
    path = [
      "/etc/profiles/per-user/lotus"
      "/home/lotus/.nix-profile"
      "/run/current-system/sw"
    ];

    serviceConfig = {
      ExecStart = "${pkgs.llm-agents.t3code}/bin/t3 serve --mode web --host 127.0.0.1 --port ${toString port}";
      User = "lotus";
      WorkingDirectory = "/home/lotus";
      Restart = "always";
      RestartSec = "5s";
      UMask = "0077";
    };
  };

  services.lferrazTailnetAccess.proxy.aliases.t3 = port;
}
