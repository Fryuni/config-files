{lib}: let
  absolutePath = lib.types.addCheck lib.types.str (lib.hasPrefix "/");
  captureName = lib.types.strMatching "[a-zA-Z0-9][a-zA-Z0-9_-]*";
  unitOptions = {
    type = lib.mkOption {
      type = lib.types.enum ["system" "user"];
      default = "system";
      description = "System or user manager that owns this service unit.";
    };
    user = lib.mkOption {
      type = lib.types.nullOr lib.types.nonEmptyStr;
      default = null;
      description = "Owner of a user unit; inherited from the enrolled home owner for Home Manager declarations.";
    };
    uid = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = "Numeric UID of a user manager; inherited for Home Manager declarations.";
    };
  };
  unitType = lib.types.submodule {
    options =
      unitOptions
      // {
        name = lib.mkOption {
          type = lib.types.nonEmptyStr;
          description = "Service unit to stop and restart around the direct backup.";
        };
      };
  };
  discoveryType = lib.types.submodule {
    options =
      unitOptions
      // {
        pattern = lib.mkOption {
          type = lib.types.nonEmptyStr;
          description = "Service-unit glob resolved against the selected manager before capture.";
        };
      };
  };
  sourceOptions = {
    paths = lib.mkOption {
      type = lib.types.listOf absolutePath;
      default = [];
      description = "Persistent directories or files owned by this service.";
    };
    units = lib.mkOption {
      type = lib.types.listOf unitType;
      default = [];
      description = "System or user service units to pause until restic finishes reading and uploading selected state.";
    };
    discoverUnits = lib.mkOption {
      type = lib.types.listOf discoveryType;
      default = [];
      description = "Service-unit patterns whose currently running instances must be paused.";
    };
    excludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Restic exclusion patterns relative to each registered source; a leading slash anchors at that source, otherwise the pattern matches at any depth.";
    };
    optional = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether an absent source is acceptable.";
    };
  };
  coordinatedType = lib.types.submodule {
    options =
      sourceOptions
      // {
        name = lib.mkOption {
          type = captureName;
          description = "Name of the application whose state accompanies the database dump.";
        };
        database = lib.mkOption {
          type = lib.types.nonEmptyStr;
          description = "PostgreSQL database to dump while this application's units are paused.";
        };
      };
  };
  pathReasonType = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = absolutePath;
        description = "Live persistent path classified by the owning service.";
      };
      reason = lib.mkOption {
        type = lib.types.nonEmptyStr;
        description = "Why this path is a scaffold or can be regenerated.";
      };
    };
  };
  captureType = named:
    lib.types.submodule ({name, ...}: {
      options =
        sourceOptions
        // {
          name = lib.mkOption ({
              type = captureName;
              description = "Unique capture name; named captures use their attribute name by default.";
            }
            // lib.optionalAttrs named {default = name;});
          kind = lib.mkOption {
            type = lib.types.enum ["files" "sqlite" "postgres" "victoria" "nix"];
            default = "files";
            description = "Consistency protocol used to capture the registered state.";
          };
          scopes = lib.mkOption {
            type = lib.types.listOf (lib.types.enum ["home" "services"]);
            default = ["services"];
            description = "Backup schedules that include this capture.";
          };
          pauseOpenWriters = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Suspend detected processes holding SQLite source files open until the consistent direct backup finishes.";
          };
          writerUid = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.unsigned;
            default = null;
            description = "UID whose open source writers are inspected; inherited for Home Manager declarations.";
          };
          watchdogDirectory = lib.mkOption {
            type = lib.types.nullOr absolutePath;
            default = null;
            description = "Override the private writer-resumption watchdog directory; omitted to use the capture staging parent.";
          };
          writerCoverageNote = lib.mkOption {
            type = lib.types.nullOr lib.types.nonEmptyStr;
            default = null;
            description = "Application-specific consistency limitations recorded in the capture manifest.";
          };
          user = lib.mkOption {
            type = lib.types.nullOr lib.types.nonEmptyStr;
            default = null;
            description = "OS account used to execute native PostgreSQL tools; omitted to use the backup account.";
          };
          socket = lib.mkOption {
            type = lib.types.nullOr absolutePath;
            default = null;
            description = "PostgreSQL socket directory; omitted to use /run/postgresql.";
          };
          port = lib.mkOption {
            type = lib.types.nullOr (lib.types.addCheck lib.types.port (port: port > 0));
            default = null;
            description = "PostgreSQL port; omitted to use 5432.";
          };
          database = lib.mkOption {
            type = lib.types.nullOr lib.types.nonEmptyStr;
            default = null;
            description = "Initial PostgreSQL connection database; omitted to use postgres. All cluster databases are captured.";
          };
          coordinated = lib.mkOption {
            type = lib.types.listOf coordinatedType;
            default = [];
            description = "Associated application state captured together with a native database dump.";
          };
          storagePath = lib.mkOption {
            type = lib.types.nullOr absolutePath;
            default = null;
            description = "Live VictoriaMetrics storage directory represented by the native snapshot.";
          };
          url = lib.mkOption {
            type = lib.types.nullOr (lib.types.strMatching "https?://.+");
            default = null;
            description = "VictoriaMetrics HTTP endpoint providing the snapshot API.";
          };
          flakePath = lib.mkOption {
            type = lib.types.nullOr absolutePath;
            default = null;
            description = "Local flake whose source and locked input closure are archived for Nix recovery.";
          };
          coveredPaths = lib.mkOption {
            type = lib.types.listOf absolutePath;
            default = [];
            description = "Additional live state represented by a native capture, for inventory checks.";
          };
        };
    });
in {
  directories = lib.mkOption {
    type = lib.types.listOf (captureType false);
    default = [];
    description = "Service-owned state registrations, concatenated across modules.";
  };
  captures = lib.mkOption {
    type = lib.types.attrsOf (captureType true);
    default = {};
    description = "Named native captures whose settings can be extended by dependent service modules.";
  };
  exclude = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "Additional absolute exclusion patterns applied to both backup scopes.";
  };
  extraPackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [];
    description = "Tools required by the registered native captures or runtime inventory.";
  };
  inventory = {
    scaffolds = lib.mkOption {
      type = lib.types.listOf pathReasonType;
      default = [];
      description = "Path/reason records for parent state directories whose children must be checked separately.";
    };
    classifiedRegenerable = lib.mkOption {
      type = lib.types.listOf pathReasonType;
      default = [];
      description = "Service-owned path/reason records for state that can be regenerated.";
    };
  };
}
