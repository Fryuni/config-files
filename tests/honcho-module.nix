{
  lib,
  pkgs,
  honchoModule,
}: let
  evaluated = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    inherit pkgs;
    modules = [
      honchoModule
      {
        system.stateVersion = "26.05";

        services.postgresql = {
          enable = true;
          ensureDatabases = ["existing"];
          ensureUsers = [
            {
              name = "existing";
              ensureDBOwnership = true;
            }
          ];
          extensions = ps: [ps.pg_cron];
        };

        services.honcho = {
          enable = true;
          environment = {
            LLM_OPENAI_API_KEY = "test-key";
          };
        };
      }
    ];
  };

  cfg = evaluated.config;

  configJson = builtins.toJSON {
    postgresqlEnable = cfg.services.postgresql.enable;
    databases = cfg.services.postgresql.ensureDatabases;
    users =
      map (user: {
        inherit (user) name ensureDBOwnership;
      })
      cfg.services.postgresql.ensureUsers;
    extensions = map builtins.toString (cfg.services.postgresql.extensions cfg.services.postgresql.package.pkgs);
    apiEnvironment = cfg.systemd.services.honcho-api.environment;
    apiAfter = cfg.systemd.services.honcho-api.after;
    apiWants = cfg.systemd.services.honcho-api.wants;
    deriverAfter = cfg.systemd.services.honcho-deriver.after;
    migrateAfter = cfg.systemd.services.honcho-migrate.after;
    postgresqlSetupAfter = cfg.systemd.services.honcho-postgresql-setup.after;
    postgresqlSetupRequires = cfg.systemd.services.honcho-postgresql-setup.requires;
    postgresqlSetupScript = cfg.systemd.services.honcho-postgresql-setup.script;
    apiServiceConfig = cfg.systemd.services.honcho-api.serviceConfig;
    migrateServiceConfig = cfg.systemd.services.honcho-migrate.serviceConfig;
  };
in
  pkgs.runCommand "honcho-module-check" {
    nativeBuildInputs = [pkgs.jq];
    inherit configJson;
  } ''
    printf '%s\n' "$configJson" > config.json

    jq -e '.postgresqlEnable == true' config.json
    jq -e '.databases | index("existing") and index("honcho")' config.json
    jq -e '.users | any(.name == "existing" and .ensureDBOwnership == true)' config.json
    jq -e '.users | any(.name == "honcho" and .ensureDBOwnership == true)' config.json
    jq -e '.extensions | any(test("pg_cron"))' config.json
    jq -e '.extensions | any(test("pgvector"))' config.json

    jq -e '.apiEnvironment.DB_CONNECTION_URI == "postgresql+psycopg:///honcho?host=/run/postgresql"' config.json
    jq -e '.apiEnvironment.AUTH_USE_AUTH == "false"' config.json
    jq -e '.apiEnvironment.LLM_OPENAI_API_KEY == "test-key"' config.json

    jq -e '.apiAfter | index("honcho-migrate.service")' config.json
    jq -e '.deriverAfter | index("honcho-migrate.service")' config.json
    jq -e '.migrateAfter | index("postgresql.service")' config.json
    jq -e '.migrateAfter | index("postgresql-setup.service")' config.json
    jq -e '.postgresqlSetupAfter | index("postgresql-setup.service")' config.json
    jq -e '.postgresqlSetupRequires | index("postgresql-setup.service")' config.json
    jq -e '(.postgresqlSetupScript | contains("ALTER DATABASE")) | not' config.json
    jq -e '.postgresqlSetupScript | test("CREATE EXTENSION IF NOT EXISTS vector")' config.json
    jq -e '(.postgresqlSetupScript | contains("CREATE USER")) | not' config.json
    jq -e '(.postgresqlSetupScript | contains("CREATE DATABASE")) | not' config.json

    jq -e '.apiServiceConfig.User == "honcho"' config.json
    jq -e '.apiServiceConfig.Group == "honcho"' config.json
    jq -e '.migrateServiceConfig.Type == "oneshot"' config.json

    test -x ${pkgs.honcho}/bin/honcho-api
    test -x ${pkgs.honcho}/bin/honcho-deriver
    test -x ${pkgs.honcho}/bin/honcho-migrate-db

    touch "$out"
  ''
