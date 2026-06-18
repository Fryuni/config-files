{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.forgejo-runner;

  settingsFormat = pkgs.formats.yaml {};

  runnerUser = "forgejo-runner";
  runnerGroup = "forgejo-runner";

  safeCharacters = lib.stringToCharacters "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-";
  escapeName = name:
    lib.concatMapStrings (char:
      if lib.elem char safeCharacters
      then char
      else "_")
    (lib.stringToCharacters name);

  serviceName = instanceName: "forgejo-runner-${escapeName instanceName}";
  stateDirectory = serviceName;
  credentialName = instanceName: connectionName: "${escapeName instanceName}-${escapeName connectionName}-${builtins.substring 0 12 (builtins.hashString "sha256" "${instanceName}/${connectionName}")}-token";

  connectionType = lib.types.submodule (_: {
    options = {
      url = lib.mkOption {
        type = lib.types.str;
        description = "Forgejo instance URL for the runner connection.";
      };

      uuid = lib.mkOption {
        type = lib.types.str;
        description = "Runner UUID registered in Forgejo for this connection.";
      };

      token = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Runner token written directly to the generated runner configuration.
          Prefer tokenFile for secrets that must stay out of the Nix store.
        '';
      };

      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Absolute runtime path to a raw token file loaded with systemd
          LoadCredential and referenced from the runner configuration through
          token_url. Use an agenix path or another runtime secret path, not a
          Nix path literal.
        '';
      };

      labels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Labels specific to this Forgejo connection.";
      };

      fetchInterval = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional fetch_interval value for this connection.";
      };
    };
  });

  instanceType = lib.types.submodule (_: {
    options = {
      enable = lib.mkEnableOption "Forgejo runner instance";

      labels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Global runner labels written to runner.labels.";
      };

      settings = lib.mkOption {
        inherit (settingsFormat) type;
        default = {};
        description = "Freeform Forgejo runner YAML settings merged with managed values.";
      };

      hostPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          bash
          coreutils
          curl
          gawk
          gitMinimal
          gnused
          nodejs
          wget
        ];
        defaultText = lib.literalExpression ''
          with pkgs; [
            bash
            coreutils
            curl
            gawk
            gitMinimal
            gnused
            nodejs
            wget
          ]
        '';
        description = "Packages added to PATH when any configured label uses the host backend.";
      };

      connections = lib.mkOption {
        type = lib.types.attrsOf connectionType;
        default = {};
        description = "Named Forgejo runner server connections.";
      };
    };
  });

  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg.instances;
  hasEnabledInstances = enabledInstances != {};

  settingsRunnerLabels = instance: instance.settings.runner.labels or [];
  runnerLabels = instance:
    if instance.labels != []
    then instance.labels
    else settingsRunnerLabels instance;

  labelsFor = instance:
    runnerLabels instance ++ lib.concatMap (connection: connection.labels) (lib.attrValues instance.connections);

  hasDockerLabels = labels: lib.any (lib.hasInfix ":docker://") labels;
  hasHostLabels = labels: lib.any (lib.hasSuffix ":host") labels;

  connectionConfig = instanceName: connectionName: connection:
    {
      inherit (connection) url uuid;
    }
    // lib.optionalAttrs (connection.token != null) {
      inherit (connection) token;
    }
    // lib.optionalAttrs (connection.tokenFile != null) {
      token_url = "file:$CREDENTIALS_DIRECTORY/${credentialName instanceName connectionName}";
    }
    // lib.optionalAttrs (connection.labels != []) {
      inherit (connection) labels;
    }
    // lib.optionalAttrs (connection.fetchInterval != null) {
      fetch_interval = connection.fetchInterval;
    };

  generatedSettings = instanceName: instance:
    instance.settings
    // {
      server =
        (instance.settings.server or {})
        // {
          connections = lib.mapAttrs (connectionConfig instanceName) instance.connections;
        };
    }
    // lib.optionalAttrs ((instance.settings ? runner) || instance.labels != []) {
      runner =
        (instance.settings.runner or {})
        // lib.optionalAttrs (instance.labels != []) {
          inherit (instance) labels;
        };
    };

  configFile = instanceName: instance:
    settingsFormat.generate "${serviceName instanceName}.yaml" (generatedSettings instanceName instance);

  loadCredentials = instanceName: instance:
    lib.concatLists (lib.mapAttrsToList (connectionName: connection:
      lib.optional (connection.tokenFile != null) "${credentialName instanceName connectionName}:${toString connection.tokenFile}")
    instance.connections);

  runtimeUnits = labels:
    lib.optionals (hasDockerLabels labels && config.virtualisation.docker.enable) ["docker.service"]
    ++ lib.optionals (hasDockerLabels labels && config.virtualisation.podman.enable) ["podman.service"];

  supplementaryGroups = labels:
    lib.optionals (hasDockerLabels labels && config.virtualisation.docker.enable) ["docker"]
    ++ lib.optionals (hasDockerLabels labels && config.virtualisation.podman.enable) ["podman"];
in {
  options.services.forgejo-runner = {
    package = lib.mkPackageOption pkgs ["forgejo-runner"] {};

    instances = lib.mkOption {
      type = lib.types.attrsOf instanceType;
      default = {};
      description = "Forgejo runner instances to run.";
    };
  };

  config = lib.mkIf hasEnabledInstances {
    assertions = lib.concatLists (lib.mapAttrsToList (instanceName: instance:
      lib.mapAttrsToList (connectionName: connection: {
        assertion = (connection.token != null) != (connection.tokenFile != null);
        message = "services.forgejo-runner.instances.${instanceName}.connections.${connectionName} must set exactly one of token or tokenFile.";
      })
      instance.connections
      ++ [
        {
          assertion = !(hasDockerLabels (labelsFor instance)) || config.virtualisation.docker.enable || config.virtualisation.podman.enable;
          message = "services.forgejo-runner.instances.${instanceName} uses docker labels, so virtualisation.docker.enable or virtualisation.podman.enable must be true.";
        }
      ])
    enabledInstances);

    users.groups.${runnerGroup} = {};
    users.users.${runnerUser} = {
      isSystemUser = true;
      group = runnerGroup;
      home = "/var/lib/forgejo-runner";
    };

    systemd.services = lib.mapAttrs' (instanceName: instance: let
      labels = labelsFor instance;
      units = runtimeUnits labels;
      stateDir = stateDirectory instanceName;
    in
      lib.nameValuePair (serviceName instanceName) {
        description = "Forgejo runner ${instanceName}";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"] ++ units;
        after = ["network-online.target"] ++ units;
        path =
          [
            pkgs.gitMinimal
            pkgs.coreutils
          ]
          ++ lib.optionals (hasHostLabels labels) instance.hostPackages;
        environment =
          {
            HOME = "/var/lib/${stateDir}";
          }
          // lib.optionalAttrs (hasDockerLabels labels && config.virtualisation.podman.enable) {
            DOCKER_HOST = "unix:///run/podman/podman.sock";
          };

        serviceConfig = {
          ExecStart = "${lib.getExe cfg.package} daemon -c ${configFile instanceName instance}";
          Restart = "on-failure";
          TimeoutStopSec = "infinity";
          User = runnerUser;
          Group = runnerGroup;
          SupplementaryGroups = supplementaryGroups labels;
          StateDirectory = stateDir;
          CacheDirectory = stateDir;
          WorkingDirectory = "/var/lib/${stateDir}";
          LoadCredential = loadCredentials instanceName instance;
        };
      })
    enabledInstances;
  };
}
