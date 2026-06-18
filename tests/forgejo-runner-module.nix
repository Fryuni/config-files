{
  forgejoRunnerModule,
  lib,
  pkgs,
}: let
  tokenSecret = pkgs.writeText "forgejo-runner-token" "raw-token-fixture";
  runnerPackage = pkgs.writeShellScriptBin "forgejo-runner" ''
    echo forgejo-runner "$@"
  '';

  evaluated = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    inherit pkgs;
    modules = [
      forgejoRunnerModule
      {
        system.stateVersion = "26.05";
        virtualisation.docker.enable = true;

        services.forgejo-runner = {
          package = runnerPackage;
          instances.codeberg = {
            enable = true;
            labels = [
              "ubuntu-latest:docker://node:26-bookworm"
              "host-shell:host"
            ];
            settings = {
              log.level = "debug";
              runner.capacity = 2;
              server.connections.codeberg.token = "must-not-survive";
            };
            hostPackages = [pkgs.bash];
            connections.codeberg = {
              url = "https://codeberg.org/";
              uuid = "11111111-2222-3333-4444-555555555555";
              tokenFile = toString tokenSecret;
              labels = ["connection-specific:docker://node:26-bookworm"];
              fetchInterval = "30s";
            };
          };
          instances."settings-only" = {
            enable = true;
            settings = {
              runner.labels = ["settings-docker:docker://node:26-bookworm"];
              container.docker_host = "automount";
            };
            connections.main = {
              url = "https://forgejo.example/";
              uuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
              token = "abcdef123456";
            };
          };
        };
      }
    ];
  };

  cfg = evaluated.config;
  service = cfg.systemd.services."forgejo-runner-codeberg";
  settingsService = cfg.systemd.services."forgejo-runner-settings-only";

  configJson = builtins.toJSON {
    tokenSecret = toString tokenSecret;
    inherit (service) after wantedBy wants environment;
    execStart = service.serviceConfig.ExecStart;
    loadCredential = service.serviceConfig.LoadCredential or [];
    stateDirectory = service.serviceConfig.StateDirectory or null;
    supplementaryGroups = service.serviceConfig.SupplementaryGroups or [];
    workingDirectory = service.serviceConfig.WorkingDirectory or null;
    servicePath = map toString service.path;
    settingsOnlyAfter = settingsService.after;
    settingsOnlyWants = settingsService.wants;
    settingsOnlySupplementaryGroups = settingsService.serviceConfig.SupplementaryGroups or [];
    settingsOnlyExecStart = settingsService.serviceConfig.ExecStart;
  };
in
  pkgs.runCommand "forgejo-runner-module-check" {
    nativeBuildInputs = [pkgs.jq pkgs.yq-go];
    tokenSecretPath = toString tokenSecret;
    inherit configJson;
  } ''
    printf '%s\n' "$configJson" > config.json

    jq -e '.wantedBy | index("multi-user.target")' config.json
    jq -e '.after | index("network-online.target")' config.json
    jq -e '.wants | index("network-online.target")' config.json
    jq -e '.after | index("docker.service")' config.json
    jq -e '.wants | index("docker.service")' config.json
    jq -e '.supplementaryGroups | index("docker")' config.json
    jq -e '.stateDirectory == "forgejo-runner-codeberg"' config.json
    jq -e '.workingDirectory == "/var/lib/forgejo-runner-codeberg"' config.json
    jq -e '.environment.HOME == "/var/lib/forgejo-runner-codeberg"' config.json
    jq -e '.servicePath | any(contains("git-minimal"))' config.json
    jq -e '.servicePath | any(contains("coreutils"))' config.json
    jq -e '.servicePath | any(contains("bash"))' config.json
    jq -e '.execStart | contains("/bin/forgejo-runner daemon -c ")' config.json
    jq -e '(.execStart | contains(" register")) | not' config.json
    jq -e --arg tokenFile "$tokenSecretPath" \
      '(.loadCredential | length == 1) and (.loadCredential[0] | endswith(":" + $tokenFile))' config.json

    execStart=$(jq -r '.execStart' config.json)
    credentialName=$(jq -r '.loadCredential[0] | split(":")[0]' config.json)
    configFile="''${execStart##* -c }"
    test -r "$configFile"
    yq -o=json '.' "$configFile" > runner.json

    jq -e '.log.level == "debug"' runner.json
    jq -e '.runner.capacity == 2' runner.json
    jq -e '.runner.labels == ["ubuntu-latest:docker://node:26-bookworm", "host-shell:host"]' runner.json
    jq -e '.server.connections.codeberg.url == "https://codeberg.org/"' runner.json
    jq -e '.server.connections.codeberg.uuid == "11111111-2222-3333-4444-555555555555"' runner.json
    jq -e '.server.connections.codeberg.labels == ["connection-specific:docker://node:26-bookworm"]' runner.json
    jq -e '.server.connections.codeberg.fetch_interval == "30s"' runner.json
    jq -e '.server.connections.codeberg.token == null' runner.json
    jq -e '.server.connections.codeberg.token_url | startswith("file:$CREDENTIALS_DIRECTORY/")' runner.json
    jq -e --arg tokenFile "$tokenSecretPath" '.server.connections.codeberg.token_url != $tokenFile' runner.json
    jq -e --arg credentialName "$credentialName" '.server.connections.codeberg.token_url == "file:$CREDENTIALS_DIRECTORY/" + $credentialName' runner.json

    jq -e '.settingsOnlyAfter | index("docker.service")' config.json
    jq -e '.settingsOnlyWants | index("docker.service")' config.json
    jq -e '.settingsOnlySupplementaryGroups | index("docker")' config.json
    settingsOnlyExecStart=$(jq -r '.settingsOnlyExecStart' config.json)
    settingsOnlyConfigFile="''${settingsOnlyExecStart##* -c }"
    test -r "$settingsOnlyConfigFile"
    yq -o=json '.' "$settingsOnlyConfigFile" > settings-only-runner.json
    jq -e '.runner.labels == ["settings-docker:docker://node:26-bookworm"]' settings-only-runner.json
    jq -e '.container.docker_host == "automount"' settings-only-runner.json
    jq -e '.server.connections.main.token == "abcdef123456"' settings-only-runner.json
    jq -e '.server.connections.main.token_url == null' settings-only-runner.json

    touch "$out"
  ''
