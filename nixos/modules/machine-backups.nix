{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.machineBackups;
  gotifySource = ../../secrets + "/restic-backup-gotify-token";
  hasGotifySecret = builtins.pathExists gotifySource;
  secretPaths = {
    ssh = "/run/agenix/storagebox-backup-ssh-key";
    password = "/run/agenix/restic-backup-password";
    gotify =
      if hasGotifySecret
      then "/run/agenix/restic-backup-gotify-token"
      else "${cfg.stateDirectory}/credentials/gotify-token";
  };
  backupSource = ../../common/backups;
  homeDeclarations = cfg.homeManager;
  # Optional schema fields use null so they remain typed without overriding the
  # capture engine's defaults or the home owner's injected user identities.
  stripNulls = value:
    if builtins.isAttrs value
    then lib.mapAttrs (_: stripNulls) (lib.filterAttrs (_: field: field != null) value)
    else if builtins.isList value
    then map stripNulls value
    else value;
  normalizeHomeCapture = rawEntry: let
    entry = stripNulls rawEntry;
    normalizeUnit = unit:
      if (unit.type or "system") == "user"
      then
        {
          inherit (cfg) user;
          uid = cfg.userUid;
        }
        // unit
      else unit;
    normalizeUnits = part:
      part
      // {units = map normalizeUnit part.units;}
      // {discoverUnits = map normalizeUnit part.discoverUnits;};
  in
    normalizeUnits entry
    // {coordinated = map normalizeUnits entry.coordinated;}
    // lib.optionalAttrs (entry.pauseOpenWriters or false) {
      writerUid = entry.writerUid or cfg.userUid;
    };
  registeredCaptures =
    map stripNulls (cfg.directories ++ lib.attrValues cfg.captures)
    ++ map normalizeHomeCapture ((homeDeclarations.directories or []) ++ lib.attrValues (homeDeclarations.captures or {}))
    ++ [
      {
        name = "recovery-inputs";
        kind = "nix";
        paths = [];
        scopes = ["services"];
        flakePath = cfg.recovery.flakePath;
      }
    ];
  registeredUnits =
    lib.concatMap (
      entry:
        (entry.units or [])
        ++ (entry.discoverUnits or [])
        ++ lib.concatMap (part: part.units ++ part.discoverUnits) (entry.coordinated or [])
    )
    registeredCaptures;
  strategyFields = {
    postgres = ["user" "socket" "port" "database"];
    victoria = ["storagePath" "url"];
    nix = ["flakePath"];
    sqlite = ["writerUid" "watchdogDirectory"];
  };
  capturesFor = scope:
    map (entry: builtins.removeAttrs entry ["scopes" "coveredPaths"])
    (lib.filter (entry: lib.elem scope entry.scopes) registeredCaptures);
  homeCaptures = capturesFor "home";
  serviceCaptures = capturesFor "services";
  excludes = [".direnv"] ++ cfg.exclude ++ (homeDeclarations.exclude or []);
  coveredPaths = lib.unique (lib.concatMap (
      entry:
        entry.paths
        ++ (entry.coveredPaths or [])
        ++ lib.concatMap (part: part.paths or []) (entry.coordinated or [])
        ++ lib.optional (entry ? storagePath) entry.storagePath
        ++ lib.optional (entry ? flakePath) entry.flakePath
    )
    registeredCaptures);
  runner = pkgs.writeShellApplication {
    name = "machine-backup";
    runtimeInputs = with pkgs;
      [python3 restic rsync openssh util-linux coreutils nix systemd]
      ++ cfg.extraPackages
      ++ (homeDeclarations.extraPackages or []);
    text = ''
      exec python3 ${backupSource}/runner.py --config ${cfg.configFile} "$@"
    '';
  };
  runtimeConfig = {
    host = config.networking.hostName;
    inherit (cfg) repository;
    passwordFile = secretPaths.password;
    inherit (cfg) stateDirectory;
    timeoutSeconds = 60;
    ssh = {
      host = "u688316.your-storagebox.de";
      user = "u688316";
      port = 23;
      identityFile = secretPaths.ssh;
      inherit (cfg) knownHostsFile;
    };
    gotify = {
      url = "https://gotify.vps1.fryuni.dev";
      tokenFile = secretPaths.gotify;
    };
    inherit (cfg) peerHost;
    capacity.quotaBytes = cfg.capacity.quotaBytes;
    inventory = {
      enabled = true;
      inherit coveredPaths;
      scaffolds = cfg.inventory.scaffolds ++ (homeDeclarations.inventory.scaffolds or []);
      classifiedRegenerable =
        [
          {
            path = cfg.stateDirectory;
            reason = "Local staging and monitor state can be rebuilt from the source machine and retained repository; notification credentials have a separate recovery provision procedure.";
          }
        ]
        ++ cfg.inventory.classifiedRegenerable ++ (homeDeclarations.inventory.classifiedRegenerable or []);
    };
    scopes = {
      home = {
        paths = [cfg.homeDirectory];
        captures = homeCaptures;
        inherit excludes;
        directExcludes = lib.concatMap (entry: entry.paths) homeCaptures;
      };
      services = {
        paths = [];
        captures = serviceCaptures;
        inherit excludes;
      };
    };
  };
  job = command: {
    wants = ["network-online.target"];
    after = ["network-online.target" "agenix.service"];
    unitConfig = {
      RequiresMountsFor = [cfg.stateDirectory cfg.homeDirectory];
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe runner} ${command}";
      User = "root";
      UMask = "0077";
      Nice = 19;
      IOSchedulingClass = "idle";
      Restart = "on-failure";
      RestartSec = "15min";
      RestartPreventExitStatus = [1];
      TimeoutStartSec = "infinity";
      TimeoutStopSec = "2min";
    };
  };
in {
  options.services.machineBackups =
    (import ../../common/backups/options.nix {inherit lib;})
    // {
      enable = lib.mkEnableOption "consistent shared restic machine backups";
      user = lib.mkOption {
        type = lib.types.str;
        default = "lotus";
        description = "Owner of backed-up home and user services.";
      };
      userUid = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = config.users.users.${cfg.user}.uid or 1000;
        description = "Numeric UID used to reach the owner's systemd user manager.";
      };
      homeDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/home/${cfg.user}";
        description = "Home directory to protect.";
      };
      recovery.flakePath = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.homeDirectory}/ZShutils";
        description = "Local flake whose configuration and locked input sources are captured for offline recovery.";
      };
      homeManager = lib.mkOption {
        type = lib.types.submodule {
          options = import ../../common/backups/options.nix {inherit lib;};
        };
        default = config.home-manager.users.${cfg.user}.services.machineBackups or {};
        description = "Home Manager backup declarations; integrated users are selected automatically, while standalone Home Manager configurations must pass their declarations explicitly.";
      };
      repository = lib.mkOption {
        type = lib.types.str;
        default = "sftp://u688316@u688316.your-storagebox.de:23/restic";
        description = "Shared, account-relative restic repository.";
      };
      stateDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/machine-backups";
        description = "Root-only capture staging and backup monitoring state.";
      };
      peerHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Other enrolled machine whose complete backup freshness is monitored.";
      };
      maintenance.enable = lib.mkEnableOption "weekly shared repository maintenance on this machine";
      capacity.quotaBytes = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1099511627776;
        description = "Contracted Storage Box capacity in bytes; compare free space against this fixed quota to count provider snapshots.";
      };
      knownHostsFile = lib.mkOption {
        type = lib.types.path;
        description = "Pinned Storage Box SSH server trust.";
        default = pkgs.writeText "storagebox-backup-known-hosts" ''
          [u688316.your-storagebox.de]:23 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs
        '';
      };
      configFile = lib.mkOption {
        type = lib.types.path;
        readOnly = true;
        default = pkgs.writeText "machine-backups.json" (builtins.toJSON runtimeConfig);
        description = "Generated credential-free runtime configuration.";
      };
    };

  config = lib.mkIf cfg.enable {
    assertions =
      [
        {
          assertion = lib.length registeredCaptures == lib.length (lib.unique (map (entry: entry.name) registeredCaptures));
          message = "services.machineBackups registrations must have unique capture names.";
        }
        {
          assertion = lib.all (entry: !(lib.elem entry.kind ["files" "sqlite"]) || entry.paths != []) registeredCaptures;
          message = "services.machineBackups file and SQLite captures require at least one source path.";
        }
        {
          assertion = lib.all (entry: entry.scopes != []) registeredCaptures;
          message = "services.machineBackups captures require at least one backup scope.";
        }
        {
          assertion = lib.all (entry: entry.kind != "victoria" || (entry ? storagePath && entry ? url)) registeredCaptures;
          message = "services.machineBackups VictoriaMetrics captures require storagePath and url.";
        }
        {
          assertion = lib.all (entry: entry.kind != "nix" || entry ? flakePath) registeredCaptures;
          message = "services.machineBackups Nix captures require flakePath.";
        }
        {
          assertion = lib.all (entry: !(entry.pauseOpenWriters or false) || (entry.kind == "sqlite" && entry ? writerUid)) registeredCaptures;
          message = "services.machineBackups pauseOpenWriters requires a SQLite capture and writerUid.";
        }
        {
          assertion = lib.all (entry: entry.kind == "postgres" || (entry.coordinated or []) == []) registeredCaptures;
          message = "services.machineBackups coordinated database captures require kind = postgres.";
        }
        {
          assertion = lib.all (unit: (unit.type or "system") != "user" || (unit ? user && unit ? uid)) registeredUnits;
          message = "services.machineBackups user units require user and uid; Home Manager declarations inherit them from the backed-up owner.";
        }
      ]
      ++ lib.mapAttrsToList (kind: fields: {
        assertion = lib.all (entry: entry.kind == kind || lib.all (field: !(builtins.hasAttr field entry)) fields) registeredCaptures;
        message = "services.machineBackups fields ${lib.concatStringsSep ", " fields} require kind = ${kind}.";
      })
      strategyFields;

    age.secrets =
      {
        storagebox-backup-ssh-key = {
          rekeyFile = ../../secrets/storagebox-backup-ssh-key;
          owner = "root";
          group = "root";
          mode = "0400";
        };
        restic-backup-password = {
          rekeyFile = ../../secrets/restic-backup-password;
          owner = "root";
          group = "root";
          mode = "0400";
        };
      }
      // lib.optionalAttrs hasGotifySecret {
        restic-backup-gotify-token = {
          rekeyFile = gotifySource;
          owner = "root";
          group = "root";
          mode = "0400";
        };
      };

    environment.systemPackages = [runner];
    systemd = {
      tmpfiles.rules = [
        "d ${cfg.stateDirectory} 0700 root root -"
        "d ${cfg.stateDirectory}/credentials 0700 root root -"
      ];
      services = {
        machine-backup-services = job "backup --scope services";
        machine-backup-home = job "backup --scope home";
        machine-backup-monitor = job "monitor";
        machine-backup-maintain = lib.mkIf cfg.maintenance.enable (job "maintain");
        machine-backup-rehearsal-reminder = lib.mkIf cfg.maintenance.enable (job "rehearsal-reminder");
      };
      timers = {
        machine-backup-services = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "*-*-* *:00:00 UTC";
            Persistent = true;
          };
        };
        machine-backup-home = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "*-*-* 00,06,12,18:00:00 UTC";
            Persistent = true;
          };
        };
        machine-backup-monitor = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "5min";
            OnUnitActiveSec = "15min";
          };
        };
        machine-backup-maintain = lib.mkIf cfg.maintenance.enable {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "Sun *-*-* 03:30:00 UTC";
            Persistent = true;
          };
        };
        machine-backup-rehearsal-reminder = lib.mkIf cfg.maintenance.enable {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "*-01,04,07,10-01 10:00:00 UTC";
            Persistent = true;
          };
        };
      };
    };
  };
}
