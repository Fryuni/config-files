{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.hermes;

  package = pkgs.lib.makeAuthWrapper pkgs.llm-agents.hermes-agent {
    OPENROUTER_API_KEY = {file = config.age.secrets.openrouter-key.path;};
    OPENAI_API_KEY = {file = config.age.secrets.openai-key.path;};
    FIRECRAWL_API_KEY = {file = config.age.secrets.firecrawl-api-key.path;};
    KIMI_API_KEY = {file = config.age.secrets.kimi-api-key.path;};
  };
in {
  options.hermes = {
    enabled = lib.mkEnableOption "Hermes agent";

    gateway.enabled = lib.mkEnableOption "Hermes messaging gateway";
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.gateway.enabled || cfg.enabled;
          message = "hermes.gateway.enabled requires hermes.enabled.";
        }
      ];
    }
    (lib.mkIf cfg.enabled {
      assertions = [
        {
          assertion = config.age.secrets ? openrouter-key;
          message = "hermes.enabled requires age.secrets.openrouter-key.";
        }
        {
          assertion = config.age.secrets ? openai-key;
          message = "hermes.enabled requires age.secrets.openai-key.";
        }
        {
          assertion = config.age.secrets ? firecrawl-api-key;
          message = "hermes.enabled requires age.secrets.firecrawl-api-key.";
        }
        {
          assertion = config.age.secrets ? kimi-api-key;
          message = "hermes.enabled requires age.secrets.kimi-api-key.";
        }
      ];

      programs.git.enable = true;

      home.packages = [
        package
      ];

      services.git-sync = {
        enable = true;
        repositories.hermes = {
          path = "${config.home.homeDirectory}/.hermes";
          uri = "git@git-ss.rudd-agama.ts.net:configs/hermes.git";
        };
      };

      systemd.user.services.hermes-gateway = lib.mkIf cfg.gateway.enabled {
        Unit = {
          Description = "Hermes Messaging Gateway";
          After = ["network-online.target"];
          Wants = ["network-online.target"];
        };

        Service = {
          ExecStart = "${package}/bin/hermes gateway run --accept-hooks";
          Restart = "always";
          RestartSec = "10s";
        };

        Install = {
          WantedBy = ["default.target"];
        };
      };
    })
  ];
}
