{
  lib,
  pkgs,
  config,
  ...
}: {
  imports = [./treehouse];

  config = lib.mkIf (pkgs.stdenv.buildPlatform.system == pkgs.stdenv.hostPlatform.system) {
    home.packages = with pkgs; [
      llm-agents.opencode
      llm-agents.agent-browser
      llm-agents.orca
      (pkgs.lib.makeAuthWrapper llm-agents.omp {
        OPENROUTER_API_KEY = {file = config.age.secrets.openrouter-key.path;};
        KIMI_API_KEY = {file = config.age.secrets.kimi-api-key.path;};
      })

      # AI auxiliary tools
      llm-agents.skills-installer
      llm-agents.workmux
      llm-agents.herdr
      llm-agents.tuicr

      uv # Needed for omp
      sqlite # Needed for many agents and tools
      tirith # Used by Hermes
    ];

    home.file.".agents".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.omp/agent/universal-link";

    programs = {
      zsh.shellAliases = {
        th = "treehouse";
        wm = "workmux";
        wma = "workmux add -o";
        wmb = "workmux add -o --background --prompt-editor";
        wmr = "workmux rm";
        wmyeet = "omp commit; workmux merge --keep --rebase --no-verify && workmux remove --force";
      };

      crush = {
        package = pkgs.llm-agents.crush;
        settings = {
          providers.loem = {
            id = "loem";
            name = "Loem";
            type = "openai-compat";
            base_url = "https://llm.loem.lferraz.dev/v1";
            discover_models = true;
          };
        };
      };
    };

    services = {
      git-sync = {
        enable = true;
        repositories = {
          oh-my-pi = {
            path = "${config.home.homeDirectory}/.omp/agent";
            uri = "git@git-ss.rudd-agama.ts.net:configs/oh-my-pi.git";
          };
        };
      };
    };
  };
}
