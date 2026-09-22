{
  config,
  lib,
  pkgs,
  ...
}: let
  port = 3773;
  graphical = config.services.xserver.enable;
  service = {
    description = "T3 Code server";
    wantedBy =
      if graphical
      then ["graphical-session.target"]
      else ["multi-user.target"];
    wants = lib.optionals (!graphical) ["network-online.target"];
    after =
      if graphical
      then ["graphical-session-pre.target"]
      else ["network-online.target"];
    partOf = lib.optionals graphical ["graphical-session.target"];
    unitConfig = lib.optionalAttrs graphical {ConditionUser = "lotus";};

    # Desktop hosts inherit the graphical environment from the user manager.
    # Headless hosts retain the boot-enabled system service.
    environment = {
      HOME = "/home/lotus";
      T3CODE_TELEMETRY_ENABLED = "false";
    };
    path = [
      "/etc/profiles/per-user/lotus"
      "/home/lotus/.nix-profile"
      "/run/current-system/sw"
    ];

    serviceConfig =
      {
        ExecStart = "${pkgs.llm-agents.t3code}/bin/t3 serve --mode web --host 127.0.0.1 --port ${toString port}";
        WorkingDirectory = "/home/lotus";
        Restart = "always";
        RestartSec = "5s";
        UMask = "0077";
      }
      // lib.optionalAttrs (!graphical) {User = "lotus";};
  };
in {
  systemd.services.t3code = lib.mkIf (!graphical) service;
  systemd.user.services.t3code = lib.mkIf graphical service;

  services.lferrazTailnetAccess.proxy.aliases.t3 = port;
}
