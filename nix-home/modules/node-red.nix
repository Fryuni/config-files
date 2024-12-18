{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.node-red;
  defaultUserDir = "${config.xdg.stateHome}/node-red";
in {
  options.services.node-red = {
    enable = mkEnableOption "the Node-RED service";

    package = mkPackageOption pkgs ["node-red"] {};

    # withNpmAndGcc = mkOption {
    #   type = types.bool;
    #   default = false;
    #   description = ''
    #     Give Node-RED access to NPM and GCC at runtime, so 'Nodes' can be
    #     downloaded and managed imperatively via the 'Palette Manager'.
    #   '';
    # };

    environment = mkOption {
      type = types.attrs;
      default = {};
      defaultText = literalExpression "{ }";
      description = "Environment variables that will be exposed to Node-RED process.";
    };

    configFile = mkOption {
      type = types.path;
      default = "${cfg.package}/lib/node_modules/node-red/packages/node_modules/node-red/settings.js";
      defaultText = literalExpression ''"''${package}/lib/node_modules/node-red/packages/node_modules/node-red/settings.js"'';
      description = ''
        Path to the JavaScript configuration file.
        See <https://github.com/node-red/node-red/blob/master/packages/node_modules/node-red/settings.js>
        for a configuration example.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 1880;
      description = "Listening port.";
    };

    userDir = mkOption {
      type = types.path;
      default = defaultUserDir;
      description = ''
        The directory to store all user data, such as flow and credential files and all library data. If left
        as the default value this directory will automatically be created before the node-red service starts,
        otherwise the sysadmin is responsible for ensuring the directory exists with appropriate ownership
        and permissions.
      '';
    };

    repo = mkOption {
      type = types.nullOr types.string;
      default = null;
    };

    safe = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to launch Node-RED in --safe mode.";
    };

    define = mkOption {
      type = types.attrs;
      default = {
        "logging.console.level" = "warn";
      };
      description = "List of settings.js overrides to pass via -D to Node-RED.";
      example = literalExpression ''
        {
          "logging.console.level" = "trace";
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.git.enable = true;

    systemd.user.services.node-red = {
      Unit = {
        Description = "Node-RED Service";
        After = ["networking.target"];
      };

      Service = {
        # Path = concatStringsSep ":" (map (p: "${p}/bin") (with pkgs; [
        #   nodejs
        #   corepack
        #   gcc
        #   git
        # ]));

        Environment = mapAttrsToList (name: value: "${name}=${value}") cfg.environment;
        Restart = "always";
        PrivateTmp = true;
        WorkingDirectory = cfg.userDir;
        StateDirectory = mkIf (cfg.userDir == defaultUserDir) "node-red";

        ExecStartPre = pkgs.writers.writeBash "prepare-node-red-state" ''
          ${let
            repo = escapeShellArg cfg.repo;
          in
            optionalString (cfg.repo != null) ''
              if [ "$(git config get remote.origin.url||true)" = ${repo} ]; then
                git add . || true
                git commit --all --message "service initialization sync" || true
              else
                rm -rf * .*
                git clone ${repo} .
              fi
              echo "node_modules" > .git/info/exclude
            ''}

          # if [ -f package.json ]; then
          #   npm update --dev
          # fi
        '';

        ExecStart = escapeShellArgs ([
            "${cfg.package}/bin/node-red"
          ]
          ++ (cli.toGNUCommandLine {} {
            safe = cfg.safe;
            settings = toString cfg.configFile;
            port = toString cfg.port;
            userDir = toString cfg.userDir;
            D = mapAttrsToList (name: value: "${name}=${value}") cfg.define;
          }));
      };

      Install = {
        WantedBy = ["multi-user.target"];
      };
    };
  };
}
