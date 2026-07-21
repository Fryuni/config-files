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
      # llm-agents.claude-code
      llm-agents.agent-browser
      (pkgs.lib.makeAuthWrapper llm-agents.omp {
        OPENROUTER_API_KEY = {file = config.age.secrets.openrouter-key.path;};
        KIMI_API_KEY = {file = config.age.secrets.kimi-api-key.path;};
      })

      # AI auxiliary tools
      llm-agents.skills-installer
      llm-agents.workmux
      llm-agents.herdr
      llm-agents.tuicr
      honcho-cli

      uv # Needed for omp
      sqlite # Needed for many agents and tools
      tirith # Used by Hermes
    ];

    home.file.".agents".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.omp/agent/universal-link";

    programs.zsh.shellAliases = {
      th = "treehouse";
      oc = "opencode";
      wm = "workmux";
      wma = "workmux add -o";
      wmb = "workmux add -o --background --prompt-editor";
      wmr = "workmux rm";
      wmyeet = "omp commit; workmux merge --keep --rebase --no-verify && workmux remove --force";
    };

    services = {
      agentsview.enable = true;
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
