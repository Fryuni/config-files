{
  config,
  lib,
  pkgs,
  ...
}: let
  port = 3773;
  tailnetCfg = config.services.lferrazTailnetAccess;
  graphical = config.services.xserver.enable;
  user = "lotus";
  userConfig = config.users.users.${user};
  homeDirectory = userConfig.home;

  publicUrl = "https://t3.${tailnetCfg.deviceName}.${tailnetCfg.publicDomain}";

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
    unitConfig = lib.optionalAttrs graphical {ConditionUser = user;};

    # Desktop hosts inherit the graphical environment from the user manager.
    # Headless hosts retain the boot-enabled system service.
    environment = {
      HOME = homeDirectory;
      T3CODE_TELEMETRY_ENABLED = "false";
    };
    path = [
      "/etc/profiles/per-user/${user}"
      "${homeDirectory}/.nix-profile"
      "/run/current-system/sw"
    ];

    serviceConfig =
      {
        ExecStart = "${pkgs.llm-agents.t3code}/bin/t3 serve --mode web --host 127.0.0.1 --port ${toString port} --public-url ${publicUrl}";
        WorkingDirectory = homeDirectory;
        Restart = "always";
        RestartSec = "5s";
        UMask = "0077";
      }
      // lib.optionalAttrs (!graphical) {User = user;};
  };
in {
  systemd.services.t3code = lib.mkIf (!graphical) service;
  systemd.user.services.t3code = lib.mkIf graphical service;

  services.lferrazTailnetAccess.proxy.aliases.t3 = port;

  services.machineBackups.directories = [
    {
      name = "t3-code";
      kind = "sqlite";
      paths = ["${homeDirectory}/.t3/userdata"];
      scopes = ["home" "services"];
      pauseOpenWriters = true;
      writerUid = userConfig.uid;
      units = [
        ({
            name = "t3code.service";
            type =
              if graphical
              then "user"
              else "system";
          }
          // lib.optionalAttrs graphical {
            inherit user;
            inherit (userConfig) uid;
          })
      ];
    }
  ];
}
