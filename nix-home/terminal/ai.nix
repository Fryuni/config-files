{
  pkgs,
  config,
  ...
}: {
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
    llm-agents.tuicr

    uv # Needed for omp
    sqlite # Needed for many agents and tools
  ];

  home.file.".agents".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.omp/agent/universal-link";

  programs.zsh.shellAliases = {
    oc = "opencode";
    # cc = "claude";
    wm = "workmux";
    wma = "workmux add -o";
    wmb = "workmux add -o --background --prompt-editor";
    wmo = "workmux open";
    wmr = "workmux rm";
  };

  services.git-sync = {
    enable = true;
    repositories = {
      oh-my-pi = {
        path = "${config.home.homeDirectory}/.omp/agent";
        uri = "git@git-ss.rudd-agama.ts.net:configs/oh-my-pi.git";
      };
    };
  };
}
