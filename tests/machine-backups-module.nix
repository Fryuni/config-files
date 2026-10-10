{
  lib,
  pkgs,
  machineBackupsModule,
}: let
  evaluate = modules:
    (lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      inherit pkgs;
      modules =
        [
          machineBackupsModule
          {
            config = {
              system.stateVersion = "26.05";
              networking.hostName = "note";
            };
            # Agenix and Home Manager are integration boundaries. Exercise their
            # public declarations without decrypting credentials or switching users.
            options = {
              age.secrets = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = {};
              };
              home-manager.users = lib.mkOption {
                type = lib.types.attrsOf lib.types.attrs;
                default = {};
              };
            };
          }
        ]
        ++ modules;
    }).config;
  directoryService = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.archiveStore;
  in {
    options.services.archiveStore = {
      enable = lib.mkEnableOption "fixture archive service";
      stateDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/archive-store";
      };
      ignoredPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["/scratch/***"];
      };
    };
    config = lib.mkIf cfg.enable {
      systemd.services.archive-store.serviceConfig = {
        ExecStart = "${pkgs.coreutils}/bin/true";
        WorkingDirectory = cfg.stateDirectory;
      };
      services.machineBackups.directories = [
        {
          name = "archive-store";
          paths = [cfg.stateDirectory];
          excludes = cfg.ignoredPaths;
          units = [{name = "archive-store.service";}];
        }
      ];
    };
  };
  independentService = {
    services.machineBackups.directories = [
      {
        name = "mail-ledger";
        kind = "sqlite";
        paths = ["/srv/mail-ledger"];
        excludes = ["/generated/***"];
        units = [{name = "mail-ledger.service";}];
      }
    ];
  };
  enrolled = [
    directoryService
    independentService
    {
      services.archiveStore.enable = true;
      services.machineBackups.enable = true;
    }
  ];
  disabled = evaluate [directoryService {services.archiveStore.enable = true;}];
  enabled = evaluate enrolled;
  moved = evaluate (enrolled
    ++ [
      {
        services.archiveStore = {
          stateDirectory = "/srv/relocated/archive";
          ignoredPaths = ["/temporary/***" "/diagnostics.log"];
        };
      }
    ]);
  disabledService = evaluate [directoryService {services.machineBackups.enable = true;}];
  uninferred = evaluate [
    {
      services = {
        machineBackups.enable = true;
        postgresql.enable = true;
        grafana.enable = true;
      };
    }
  ];
  home =
    (lib.evalModules {
      modules = [
        ../nix-home/modules/machine-backups.nix
        {
          services.machineBackups = {
            directories = [
              {
                name = "user-journal";
                kind = "sqlite";
                paths = ["/srv/alice/.local/state/user-journal"];
                scopes = ["home" "services"];
                units = [
                  {
                    name = "user-journal.service";
                    type = "user";
                  }
                  {
                    name = "journal-sidecar.service";
                    type = "system";
                  }
                ];
                discoverUnits = [
                  {
                    pattern = "user-journal-worker-*.service";
                    type = "user";
                  }
                ];
                pauseOpenWriters = true;
                excludes = ["/scratch/***"];
              }
            ];
            exclude = ["/srv/alice/.cache"];
            extraPackages = [pkgs.sqlite];
            inventory.classifiedRegenerable = [
              {
                path = "/srv/alice/.local/state/journal-index";
                reason = "The journal rebuilds its search index.";
              }
            ];
          };
        }
      ];
    }).config;
  nativeDatabase = {
    services.machineBackups = {
      captures.catalog-db = {
        kind = "postgres";
        paths = [];
        user = "catalog-user";
        socket = "/run/catalog-db";
        port = 5434;
        database = "catalog";
        coveredPaths = ["/srv/catalog-db/cluster"];
      };
      extraPackages = [pkgs.postgresql_18];
      inventory.scaffolds = [
        {
          path = "/srv/catalog-db";
          reason = "The native dump covers the cluster; inspect other children.";
        }
      ];
    };
  };
  databaseConsumer = {
    services.machineBackups.captures.catalog-db.coordinated = [
      {
        name = "shop-records";
        database = "shop";
        paths = ["/srv/shop-records"];
        units = [{name = "shop-worker.service";} {name = "shop.service";}];
      }
    ];
  };
  otherDatabaseConsumer = {
    services.machineBackups.captures.catalog-db.coordinated = [
      {
        name = "media-records";
        database = "media";
        paths = ["/srv/media-records"];
        units = [{name = "media.service";}];
      }
    ];
  };
  owner = evaluate [
    nativeDatabase
    databaseConsumer
    otherDatabaseConsumer
    {
      networking.hostName = lib.mkForce "loem";
      home-manager.users.alice = home;
      services.machineBackups = {
        enable = true;
        maintenance.enable = true;
        homeDirectory = "/srv/alice";
        user = "alice";
        userUid = 2000;
        exclude = ["/srv/shared/build-cache"];
        captures.telemetry-db = {
          kind = "victoria";
          paths = [];
          url = "http://127.0.0.1:18428";
          storagePath = "/srv/telemetry-db";
        };
        inventory.classifiedRegenerable = [
          {
            path = "/srv/catalog-db/cache";
            reason = "Catalog pages are regenerated from the database.";
          }
        ];
      };
    }
  ];
  standaloneOwner = evaluate [
    {
      services.machineBackups = {
        enable = true;
        user = "alice";
        userUid = 2000;
        homeDirectory = "/srv/alice";
        homeManager = home.services.machineBackups;
      };
    }
  ];
  future = evaluate [
    {
      networking.hostName = lib.mkForce "future";
      services.machineBackups.enable = true;
    }
  ];
  duplicate = evaluate (enrolled ++ [independentService]);
  emptySource = evaluate [
    {
      services.machineBackups = {
        enable = true;
        directories = [{name = "missing-source";}];
      };
    }
  ];
  emptyScopes = evaluate [
    {
      services.machineBackups = {
        enable = true;
        directories = [
          {
            name = "missing-scope";
            paths = ["/srv/missing-scope"];
            scopes = [];
          }
        ];
      };
    }
  ];
  invalidName = evaluate [
    {
      services.machineBackups = {
        enable = true;
        directories = [
          {
            name = "nested/capture";
            paths = ["/srv/invalid-name"];
          }
        ];
      };
    }
  ];
  dottedName = evaluate [
    {
      services.machineBackups = {
        enable = true;
        directories = [
          {
            name = "capture.with-dot";
            paths = ["/srv/dotted-name"];
          }
        ];
      };
    }
  ];
  missingName = evaluate [
    {
      services.machineBackups = {
        enable = true;
        directories = [{paths = ["/srv/missing-name"];}];
      };
    }
  ];
  declarations = settings:
    (lib.evalModules {
      modules = [../nix-home/modules/machine-backups.nix {services.machineBackups = settings;}];
    }).config.services.machineBackups;
  rejectsDeclaration = settings: !(builtins.tryEval (builtins.deepSeq (declarations settings) true)).success;
  sourceFixture = {
    name = "typed-source";
    kind = "sqlite";
    paths = ["/srv/typed-source"];
  };
  invalidCapture = capture:
    evaluate [
      {
        services.machineBackups = {
          enable = true;
          directories = [({name = "invalid-capture";} // capture)];
        };
      }
    ];
  missingSnapshotUrl = invalidCapture {
    kind = "victoria";
    storagePath = "/srv/telemetry-db";
  };
  missingSnapshotStorage = invalidCapture {
    kind = "victoria";
    url = "http://127.0.0.1:18428";
  };
  missingFlakePath = invalidCapture {kind = "nix";};
  missingWriterUid = invalidCapture {
    kind = "sqlite";
    paths = ["/srv/typed-source"];
    pauseOpenWriters = true;
  };
  unsupportedWriterStrategy = invalidCapture {
    kind = "files";
    paths = ["/srv/typed-source"];
    pauseOpenWriters = true;
    writerUid = 1000;
  };
  missingUnitIdentity = invalidCapture {
    paths = ["/srv/typed-source"];
    units = [
      {
        name = "typed-source.service";
        type = "user";
      }
    ];
  };
  wrongNativeFields = invalidCapture {
    paths = ["/srv/typed-source"];
    socket = "/run/catalog-db";
  };
  wrongCoordinatedStrategy = invalidCapture {
    kind = "sqlite";
    paths = ["/srv/typed-source"];
    coordinated = [
      {
        name = "dependent";
        database = "catalog";
        paths = ["/srv/dependent"];
      }
    ];
  };
  failedAssertion = configuration: message:
    lib.any (entry: !entry.assertion && lib.hasInfix message entry.message) configuration.assertions;
  backupCommand = configuration:
    lib.findFirst (package: (package.name or "") == "machine-backup")
    (throw "The module must install machine-backup")
    configuration.environment.systemPackages;
  check = condition: message:
    if condition
    then true
    else throw message;
  checks = [
    (check (!(disabled.systemd.services ? machine-backup-home)) "Disabled machines must have no backup job")
    (check (!(disabled.systemd.timers ? machine-backup-services)) "Disabled machines must have no backup timer")
    (check (disabled.age.secrets == {}) "Unenrolled machines must receive no backup credentials")
    (check (lib.length disabled.services.machineBackups.directories == 1) "Services may declare state without enrolling the machine")
    (check (lib.length enabled.services.machineBackups.directories == 2) "Independent service declarations must concatenate")
    (check (disabledService.services.machineBackups.directories == []) "A disabled service must contribute no state")
    (check (enabled.systemd.timers.machine-backup-services.timerConfig.OnCalendar == "*-*-* *:00:00 UTC") "Services must be scheduled hourly")
    (check (enabled.systemd.timers.machine-backup-home.timerConfig.OnCalendar == "*-*-* 00,06,12,18:00:00 UTC") "Home must be scheduled every six hours")
    (check enabled.systemd.timers.machine-backup-home.timerConfig.Persistent "Home must catch up after downtime")
    (check (enabled.systemd.services.machine-backup-services.serviceConfig.Nice == 19) "Backups must run at low CPU priority")
    (check (enabled.systemd.services.machine-backup-services.serviceConfig.IOSchedulingClass == "idle") "Backups must run at low IO priority")
    (check (enabled.systemd.services.machine-backup-services.serviceConfig.RestartSec == "15min") "Transient failures must retry after fifteen minutes")
    (check (enabled.systemd.services.machine-backup-services.serviceConfig.RestartPreventExitStatus == [1]) "Permanent failures must wait for intervention")
    (check (enabled.age.secrets.storagebox-backup-ssh-key.mode == "0400") "The backup access identity must be root-only")
    (check (!(enabled.systemd.services ? machine-backup-maintain)) "Ordinary clients must not prune the shared repository")
    (check (owner.systemd.timers.machine-backup-maintain.timerConfig.OnCalendar == "Sun *-*-* 03:30:00 UTC") "The maintenance owner must perform weekly repository maintenance")
    (check (!(enabled.systemd.timers.machine-backup-home.timerConfig.WakeSystem or false)) "Notebook backups must not wake the machine")
    (check (future.age.secrets.storagebox-backup-ssh-key.rekeyFile == enabled.age.secrets.storagebox-backup-ssh-key.rekeyFile) "New clients must receive the existing backup access identity")
    (check (future.services.machineBackups.directories == [] && future.services.machineBackups.captures == {}) "Future clients must opt in to service-specific state")
    (check (lib.hasInfix (builtins.unsafeDiscardStringContext "${pkgs.postgresql_18}/bin") (backupCommand owner).text) "Native capture tools must be available to the runner")
    (check (lib.hasInfix (builtins.unsafeDiscardStringContext "${pkgs.sqlite}/bin") (backupCommand owner).text) "Home Manager capture tools must be available to the runner")
    (check (lib.hasInfix (builtins.unsafeDiscardStringContext "${pkgs.sqlite}/bin") (backupCommand standaloneOwner).text) "Standalone Home Manager capture tools must be available to the runner")
    (check (failedAssertion duplicate "unique capture names") "Duplicate capture names must be rejected")
    (check (failedAssertion emptySource "at least one source path") "File captures with no source must be rejected")
    (check (failedAssertion emptyScopes "at least one backup scope") "Captures without a schedule must be rejected")
    (check (!(builtins.tryEval (builtins.deepSeq invalidName.services.machineBackups.directories true)).success) "Unsafe capture names must be rejected")
    (check (!(builtins.tryEval (builtins.deepSeq dottedName.services.machineBackups.directories true)).success) "Capture names must match the runtime capture protocol")
    (check (!(builtins.tryEval (builtins.deepSeq missingName.services.machineBackups.directories true)).success) "Directory captures must declare an explicit name")
    (check (rejectsDeclaration {directories = [(sourceFixture // {pauseOpenWriter = true;})];}) "Misspelled capture safeguards must be rejected")
    (check (rejectsDeclaration {
      directories = [
        (sourceFixture
          // {
            units = [
              {
                name = "typed-source.service";
                type = "user";
                usre = "alice";
              }
            ];
          })
      ];
    }) "Misspelled unit identities must be rejected")
    (check (rejectsDeclaration {directories = [(sourceFixture // {discoverUnits = [{patern = "typed-source-*.service";}];})];}) "Misspelled discovery fields must be rejected")
    (check (rejectsDeclaration {
      captures.database = {
        kind = "postgres";
        coordinated = [
          {
            name = "dependent";
            paths = ["/srv/dependent"];
          }
        ];
      };
    }) "Coordinated PostgreSQL captures must declare their database")
    (check (rejectsDeclaration {
      captures.database = {
        kind = "postgres";
        port = "5432";
      };
    }) "Native database connection values must have the declared types")
    (check (rejectsDeclaration {
      inventory.classifiedRegenerable = [
        {
          path = "/srv/cache";
          resaon = "Regenerable cache.";
        }
      ];
    }) "Regenerable state classifications must have typed path/reason records")
    (check (rejectsDeclaration {directories = [(sourceFixture // {paths = ["relative/source"];})];}) "Capture sources must be absolute paths")
    (check (failedAssertion missingSnapshotUrl "require storagePath and url") "VictoriaMetrics captures must declare their snapshot URL")
    (check (failedAssertion missingSnapshotStorage "require storagePath and url") "VictoriaMetrics captures must declare their storage path")
    (check (failedAssertion missingFlakePath "require flakePath") "Nix captures must declare their recovery flake")
    (check (failedAssertion missingWriterUid "requires a SQLite capture and writerUid") "Writer suspension must identify the source writers' UID")
    (check (failedAssertion unsupportedWriterStrategy "requires a SQLite capture and writerUid") "Unsupported writer suspension strategies must be rejected")
    (check (failedAssertion missingUnitIdentity "user units require user and uid") "NixOS user units must declare their owner and UID")
    (check (failedAssertion wrongNativeFields "require kind = postgres") "Native connection settings must match the capture strategy")
    (check (failedAssertion wrongCoordinatedStrategy "coordinated database captures require kind = postgres") "Associated database captures must use the PostgreSQL protocol")
  ];
in
  assert lib.all (value: value) checks;
    pkgs.runCommand "machine-backups-module-check" {
      nativeBuildInputs = [pkgs.jq];
      configFile = enabled.services.machineBackups.configFile;
      movedConfigFile = moved.services.machineBackups.configFile;
      disabledServiceConfigFile = disabledService.services.machineBackups.configFile;
      uninferredConfigFile = uninferred.services.machineBackups.configFile;
      ownerConfigFile = owner.services.machineBackups.configFile;
      standaloneOwnerConfigFile = standaloneOwner.services.machineBackups.configFile;
    } ''
      jq -e '.repository == "sftp://u688316@u688316.your-storagebox.de:23/restic"' "$configFile"
      jq -e '.scopes.home.paths == ["/home/lotus"] and .scopes.home.captures == []' "$configFile"
      jq -e '.scopes.home.excludes == [".direnv"] and .scopes.services.excludes == [".direnv"]' "$configFile"
      jq -e '.scopes.services.captures | any(.name == "archive-store" and .kind == "files" and .paths == ["/var/lib/archive-store"] and .excludes == ["/scratch/***"] and .units[0].name == "archive-store.service")' "$configFile"
      jq -e '.scopes.services.captures | any(.name == "mail-ledger" and .kind == "sqlite" and .paths == ["/srv/mail-ledger"] and .excludes == ["/generated/***"])' "$configFile"
      jq -e '.scopes.services.captures | any(.name == "recovery-inputs" and .kind == "nix" and .flakePath == "/home/lotus/ZShutils")' "$configFile"
      jq -e '.scopes.services.captures | any(.name == "archive-store" and .paths == ["/srv/relocated/archive"] and .excludes == ["/temporary/***", "/diagnostics.log"])' "$movedConfigFile"
      jq -e '.inventory.coveredPaths | index("/srv/relocated/archive") != null and index("/var/lib/archive-store") == null' "$movedConfigFile"
      jq -e '[.scopes.services.captures[].name] == ["recovery-inputs"]' "$disabledServiceConfigFile"
      jq -e '[.scopes.services.captures[].name] == ["recovery-inputs"]' "$uninferredConfigFile"
      jq -e '.ssh.identityFile == "/run/agenix/storagebox-backup-ssh-key" and .passwordFile == "/run/agenix/restic-backup-password"' "$configFile"
      jq -e '.scopes.home.paths == ["/srv/alice"]' "$ownerConfigFile"
      jq -e '.scopes.home.directExcludes == ["/srv/alice/.local/state/user-journal"]' "$ownerConfigFile"
      jq -e '.scopes.home.excludes == [".direnv", "/srv/shared/build-cache", "/srv/alice/.cache"] and .scopes.services.excludes == .scopes.home.excludes' "$ownerConfigFile"
      jq -e '[.scopes.home.captures[], .scopes.services.captures[]] | map(select(.name == "user-journal")) | length == 2 and all(.[]; .kind == "sqlite" and .excludes == ["/scratch/***"] and .units[0] == {name: "user-journal.service", type: "user", user: "alice", uid: 2000} and .units[1] == {name: "journal-sidecar.service", type: "system"} and .discoverUnits[0] == {pattern: "user-journal-worker-*.service", type: "user", user: "alice", uid: 2000} and .pauseOpenWriters == true and .writerUid == 2000)' "$ownerConfigFile"
      jq -e '.scopes.services.captures | map(select(.name == "catalog-db")) | length == 1 and .[0].kind == "postgres" and .[0].user == "catalog-user" and .[0].socket == "/run/catalog-db" and .[0].port == 5434 and .[0].database == "catalog" and (.[0].coordinated | map(.name) | sort) == ["media-records", "shop-records"]' "$ownerConfigFile"
      jq -e '.scopes.services.captures[] | select(.name == "catalog-db") | .coordinated | any(.name == "shop-records" and .database == "shop" and .paths == ["/srv/shop-records"] and [.units[].name] == ["shop-worker.service", "shop.service"])' "$ownerConfigFile"
      jq -e '.scopes.services.captures | any(.name == "telemetry-db" and .kind == "victoria" and .url == "http://127.0.0.1:18428" and .storagePath == "/srv/telemetry-db")' "$ownerConfigFile"
      jq -e '.inventory.coveredPaths as $paths | ["/srv/catalog-db/cluster", "/srv/shop-records", "/srv/media-records", "/srv/telemetry-db", "/srv/alice/.local/state/user-journal", "/srv/alice/ZShutils"] | all(.[]; . as $path | $paths | index($path) != null)' "$ownerConfigFile"
      jq -e '.inventory.scaffolds | any(.path == "/srv/catalog-db" and (.reason | length) > 0)' "$ownerConfigFile"
      jq -e '.inventory.classifiedRegenerable | any(.path == "/srv/catalog-db/cache") and any(.path == "/srv/alice/.local/state/journal-index") and any(.path == "/var/lib/machine-backups")' "$ownerConfigFile"
      jq -e '[.scopes.home.captures[], .scopes.services.captures[]] | all(.[]; (has("scopes") or has("coveredPaths")) | not)' "$ownerConfigFile"
      jq -e --slurpfile standalone "$standaloneOwnerConfigFile" '.scopes.home.captures == $standalone[0].scopes.home.captures' "$ownerConfigFile"
      jq -e '.scopes.services.captures | any(.name == "user-journal" and .units[0].user == "alice" and .units[0].uid == 2000 and .writerUid == 2000)' "$standaloneOwnerConfigFile"
      jq -e '[.scopes.home.captures[], .scopes.services.captures[]] | [.. | select(. == null)] | length == 0' "$ownerConfigFile"
      jq -e '.capacity.quotaBytes == 1099511627776' "$ownerConfigFile"
      touch $out
    ''
