{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.honcho;

  databaseUser =
    if cfg.database.user == null
    then cfg.user
    else cfg.database.user;

  generatedLocalConnectionUri = "postgresql+psycopg:///${cfg.database.name}?host=/run/postgresql";
  connectionUri =
    if cfg.database.connectionUri != null
    then cfg.database.connectionUri
    else generatedLocalConnectionUri;

  boolToEnv = value:
    if value
    then "true"
    else "false";

  sqlLiteral = value: "'${lib.replaceStrings ["'"] ["''"] value}'";
  alterDatabaseOwnerSql = "SELECT format('ALTER DATABASE %I OWNER TO %I', ${sqlLiteral cfg.database.name}, ${sqlLiteral databaseUser})";

  valueToEnv = value:
    if lib.isBool value
    then boolToEnv value
    else toString value;

  environment = lib.mapAttrs (_: valueToEnv) (
    {
      AUTH_USE_AUTH = cfg.auth.enable;
      DB_CONNECTION_URI = connectionUri;
      HOME = "/var/lib/honcho";
      LOCAL_METRICS_FILE = "/var/lib/honcho/metrics.jsonl";
      LOG_LEVEL = cfg.logLevel;
      VECTOR_STORE_LANCEDB_PATH = "/var/lib/honcho/lancedb";
    }
    // cfg.environment
  );

  postgresql = config.services.postgresql.package;
  psql = "${postgresql}/bin/psql";
  honchoApi = lib.getExe' cfg.package "honcho-api";
  honchoDeriver = lib.getExe' cfg.package "honcho-deriver";
  honchoMigrate = lib.getExe' cfg.package "honcho-migrate-db";

  commonServiceConfig = {
    User = cfg.user;
    Group = cfg.group;
    StateDirectory = "honcho";
    CacheDirectory = "honcho";
    WorkingDirectory = "${cfg.package}/share/honcho";
    EnvironmentFile = cfg.environmentFiles;
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    RestrictSUIDSGID = true;
  };

  localDatabaseUnits = lib.optionals cfg.database.createLocally [
    "postgresql.service"
    "postgresql-setup.service"
    "honcho-postgresql-setup.service"
  ];
in {
  options.services.honcho = {
    enable = lib.mkEnableOption "Honcho self-hosted memory API";

    package = lib.mkPackageOption pkgs ["honcho"] {};

    user = lib.mkOption {
      type = lib.types.str;
      default = "honcho";
      description = ''
        Unix user that runs Honcho. When using the generated local PostgreSQL
        connection URI, this must match the PostgreSQL role for peer auth.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "honcho";
      description = "Unix group that runs Honcho.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the Honcho API listens on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port the Honcho API listens on.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Honcho API port in the firewall.";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum ["CRITICAL" "ERROR" "WARNING" "INFO" "DEBUG" "NOTSET"];
      default = "INFO";
      description = "Honcho log level.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [
        lib.types.bool
        lib.types.int
        lib.types.path
        lib.types.str
      ]);
      default = {};
      description = ''
        Extra environment variables for the Honcho API, migration, and deriver
        processes. Use this for non-secret model/provider configuration.
      '';
      example = lib.literalExpression ''
        {
          LLM_OPENAI_API_KEY = "sk-...";
          DERIVER_MODEL_CONFIG__TRANSPORT = "openai";
          DERIVER_MODEL_CONFIG__MODEL = "google/gemini-2.5-flash";
          DERIVER_MODEL_CONFIG__OVERRIDES__BASE_URL = "https://openrouter.ai/api/v1";
        }
      '';
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = ''
        Environment files loaded by systemd. Put secrets such as LLM API keys
        here instead of directly in the Nix store.
      '';
      example = lib.literalExpression ''
        [ config.age.secrets.honcho-env.path ]
      '';
    };

    auth.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether Honcho authentication is enabled. If true, provide
        AUTH_JWT_SECRET through environment or environmentFiles.
      '';
    };

    deriver.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run Honcho's background deriver worker.";
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Configure the NixOS PostgreSQL service with a Honcho database, role,
          and the pgvector extension. Disable this when using an external
          PostgreSQL server and set database.connectionUri.
        '';
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "honcho";
        description = "PostgreSQL database name used by Honcho.";
      };

      user = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          PostgreSQL role used by Honcho. Defaults to services.honcho.user so
          NixOS PostgreSQL peer authentication works without storing a password.
        '';
      };

      connectionUri = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Full SQLAlchemy PostgreSQL connection URI. Leave null with
          database.createLocally enabled to use the generated local peer-auth
          URI. Set this when using a remote database or password auth.
        '';
        example = "postgresql+psycopg://honcho:secret@db.example.com:5432/honcho";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.database.createLocally || cfg.database.connectionUri != null;
        message = "services.honcho.database.connectionUri must be set when services.honcho.database.createLocally is false.";
      }
      {
        assertion = cfg.database.connectionUri != null || databaseUser == cfg.user;
        message = "services.honcho.database.user must match services.honcho.user when using the generated local PostgreSQL peer-auth connection URI.";
      }
    ];

    users.groups.${cfg.group} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = "/var/lib/honcho";
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];

    services.postgresql = lib.mkIf cfg.database.createLocally {
      enable = true;
      ensureDatabases = [cfg.database.name];
      ensureUsers = [
        {
          name = databaseUser;
          ensureDBOwnership = databaseUser == cfg.database.name;
        }
      ];
      extensions = ps: [ps.pgvector];
    };

    systemd.services.honcho-postgresql-setup = lib.mkIf cfg.database.createLocally {
      description = "Prepare PostgreSQL objects for Honcho";
      after = ["postgresql-setup.service"];
      requires = ["postgresql-setup.service"];
      before = ["honcho-migrate.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
      };
      script = ''
        set -euo pipefail

        ${lib.optionalString (databaseUser != cfg.database.name) ''
          alterDatabaseSql="$(${psql} -v ON_ERROR_STOP=1 --dbname postgres --tuples-only --no-align \
            --command ${lib.escapeShellArg alterDatabaseOwnerSql})"
          ${psql} -v ON_ERROR_STOP=1 --dbname postgres --command "$alterDatabaseSql"
        ''}

        ${psql} -v ON_ERROR_STOP=1 --dbname ${lib.escapeShellArg cfg.database.name} \
          --command 'CREATE EXTENSION IF NOT EXISTS vector'
      '';
    };

    systemd.services.honcho-migrate = {
      description = "Run Honcho database migrations";
      after = ["network-online.target"] ++ localDatabaseUnits;
      wants = ["network-online.target"];
      requires = localDatabaseUnits;
      inherit environment;
      serviceConfig =
        commonServiceConfig
        // {
          Type = "oneshot";
          ExecStart = honchoMigrate;
        };
    };

    systemd.services.honcho-api = {
      description = "Honcho API server";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "honcho-migrate.service"] ++ localDatabaseUnits;
      wants = ["network-online.target" "honcho-migrate.service"];
      requires = ["honcho-migrate.service"] ++ localDatabaseUnits;
      inherit environment;
      serviceConfig =
        commonServiceConfig
        // {
          ExecStart = "${honchoApi} --host ${lib.escapeShellArg cfg.host} --port ${toString cfg.port}";
          Restart = "on-failure";
          RestartSec = 5;
        };
    };

    systemd.services.honcho-deriver = lib.mkIf cfg.deriver.enable {
      description = "Honcho deriver background worker";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "honcho-migrate.service"] ++ localDatabaseUnits;
      wants = ["network-online.target" "honcho-migrate.service"];
      requires = ["honcho-migrate.service"] ++ localDatabaseUnits;
      inherit environment;
      serviceConfig =
        commonServiceConfig
        // {
          ExecStart = honchoDeriver;
          Restart = "on-failure";
          RestartSec = 5;
        };
    };
  };
}
