{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    llm-agents.crush
    llm-agents.opencode
    # llm-agents.claude-code
    llm-agents.agent-browser
    (pkgs.lib.makeAuthWrapper llm-agents.omp {
      # OPENROUTER_API_KEY = {file = config.age.secrets.openrouter-key.path;};
      KIMI_API_KEY = {file = config.age.secrets.kimi-api-key.path;};
    })
    (pkgs.lib.makeAuthWrapper mods {
      OPENAI_API_KEY = {file = config.age.secrets.openai-key.path;};
    })

    # AI auxiliary tools
    llm-agents.skills-installer
    llm-agents.workmux
    llm-agents.tuicr

    uv # Needed for omp
  ];

  programs.zsh.shellAliases = {
    clear-mods-conversations = "rm -rf ~/.local/share/mods/conversations";
    oc = "opencode";
    # cc = "claude";
    wm = "workmux";
    wma = "workmux add -o";
    wmb = "workmux add -o --background --prompt-editor";
    wmd = "workmux dashboard";
  };

  home.file.".config/crush/crush.json".text = builtins.toJSON {
    mcp = {
      github = {
        type = "http";
        url = "https://api.githubcopilot.com/mcp/";
        headers = {Authorization = "Bearer $(gh auth token)";};
      };
    };
    lsp = {
      go = {
        enabled = true;
        command = "gopls";
      };
      nix = {
        enabled = true;
        command = "nil";
      };
    };
    permissions = {allowed_tools = ["view" "ls" "grep"];};
    options = {
      skills_paths = ["~/.config/crush/skills" "./agents/skills"];
      attribution = {
        trailer_style = "none";
        generated_with = true;
      };
    };
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
