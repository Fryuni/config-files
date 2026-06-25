{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption mkEnableOption mkPackageOption types;
  cfg = config.services.agentsview;
  pgUrl =
    if cfg.postgres.url == null
    then ""
    else cfg.postgres.url;
  pgMachine =
    if cfg.postgres.machine == null
    then ""
    else cfg.postgres.machine;
  pgEnv = [
    "AGENTSVIEW_PG_URL=${pgUrl}"
    "AGENTSVIEW_PG_SCHEMA=${cfg.postgres.schema}"
  ];
  args =
    [
      "${cfg.package}/bin/agentsview"
    ]
    ++ lib.optionals cfg.postgres.enable [
      "pg"
    ]
    ++ [
      "serve"
      "--no-browser"
      "--host"
      cfg.host
      "--port"
      (toString cfg.port)
    ]
    ++ lib.optionals (cfg.publicOrigin != null) [
      "--public-origin"
      cfg.publicOrigin
    ];
  pushArgs = [
    "${cfg.package}/bin/agentsview"
    "pg"
    "push"
    "--watch"
    "--interval"
    cfg.postgres.push.interval
  ];
  pushAllowInsecureConfig = pkgs.writeText "agentsview-pg-push-config.toml" ''
    [pg]
    allow_insecure = true
  '';
  pushPrepareConfig = pkgs.writeShellScript "agentsview-pg-push-prepare-config" ''
    set -eu
    install -d -m 0700 ${lib.escapeShellArg cfg.postgres.push.dataDir}
    install -m 0600 ${pushAllowInsecureConfig} ${lib.escapeShellArg cfg.postgres.push.dataDir}/config.toml
  '';
in {
  options.services.agentsview = {
    enable = mkEnableOption "agentsview service";

    package = mkPackageOption pkgs.llm-agents ["agentsview"] {};

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host address for agentsview to listen on.";
    };

    port = mkOption {
      type = types.port;
      default = 3377;
      description = "Port for agentsview to listen on.";
    };

    publicOrigin = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Public origin URL agentsview advertises for browser access.";
    };

    postgres = {
      enable = mkEnableOption "PostgreSQL backend for agentsview";

      url = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "PostgreSQL connection URL used by agentsview.";
      };

      schema = mkOption {
        type = types.str;
        default = "agentsview";
        description = "PostgreSQL schema used by agentsview.";
      };

      machine = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Machine name used when pushing agentsview data to PostgreSQL.";
      };

      allowInsecure = mkOption {
        type = types.bool;
        default = false;
        description = "Allow insecure PostgreSQL connections for agentsview push.";
      };

      push = {
        enable = mkEnableOption "agentsview PostgreSQL push service";

        interval = mkOption {
          type = types.str;
          default = "30m";
          description = "Minimum interval between periodic agentsview PostgreSQL pushes.";
        };

        dataDir = mkOption {
          type = types.str;
          default = "${config.xdg.stateHome}/agentsview-pg-push";
          description = "Data directory used by the agentsview PostgreSQL push service.";
        };
      };
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.postgres.enable || cfg.postgres.push.enable) || cfg.postgres.url != null;
          message = "services.agentsview.postgres.url must be set when PostgreSQL serve or push is enabled.";
        }
        {
          assertion = !cfg.postgres.push.enable || cfg.postgres.machine != null;
          message = "services.agentsview.postgres.machine must be set when services.agentsview.postgres.push.enable is true.";
        }
      ];
    }

    (mkIf cfg.enable {
      home.packages = [cfg.package];

      systemd.user.services.agentsview = {
        Unit = {
          Description = "agentsview service";
        };

        Service =
          {
            ExecStart = lib.escapeShellArgs args;
            Restart = "always";
          }
          // lib.optionalAttrs (cfg.postgres.enable && cfg.postgres.url != null) {
            Environment = pgEnv;
          };

        Install = {
          WantedBy = ["default.target"];
        };
      };
    })

    (mkIf cfg.postgres.push.enable {
      systemd.user.services.agentsview-pg-push = {
        Unit = {
          Description = "agentsview PostgreSQL push service";
        };

        Service =
          {
            ExecStart = lib.escapeShellArgs pushArgs;
            Restart = "always";
            RestartSec = "10s";
            Environment =
              pgEnv
              ++ [
                "AGENTSVIEW_PG_MACHINE=${pgMachine}"
                "AGENTSVIEW_DATA_DIR=${cfg.postgres.push.dataDir}"
              ];
          }
          // lib.optionalAttrs cfg.postgres.allowInsecure {
            ExecStartPre = pushPrepareConfig;
          };

        Install = {
          WantedBy = ["default.target"];
        };
      };
    })
  ];
}
