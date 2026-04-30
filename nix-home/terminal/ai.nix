{
  pkgs,
  config,
  ...
}: let
  makeAuthWrapper = pkg: envMap:
    (pkgs.symlinkJoin {
      name = "${pkg.name}-authenticated";
      nativeBuildInputs = [pkgs.makeWrapper pkgs.coreutils];
      paths = [pkg];
      postBuild = let
        inherit (builtins) isString isAttrs attrNames concatStringsSep;

        mkExport = name: value:
          if isString value
          then ''--set ${name} "${value}"''
          else if isAttrs value && value ? file
          then ''--run 'export ${name}="$(cat "${value.file}")"' ''
          else throw "Invalid env value for ${name}: expected string or { file = path; }";

        exports = map (name: mkExport name envMap.${name}) (attrNames envMap);
        args = concatStringsSep " \\\n" exports + "\n";
      in ''
        for file in ${pkg}/bin/*; do
          originalFile="$(readlink -f "$file")"
          newOut="$out/bin/$(basename $file)"
          rm -rf "$newOut"
          makeWrapper "$originalFile" "$newOut" \
            ${args}
        done
      '';
    }).overrideAttrs (old: {
      inherit (pkg) meta;
    });
in {
  home.packages = with pkgs; [
    llm-agents.crush
    llm-agents.opencode
    llm-agents.claude-code
    llm-agents.agent-browser
    (makeAuthWrapper llm-agents.hermes-agent {
      OPENROUTER_API_KEY = {file = config.age.secrets.openrouter-key.path;};
      OPENAI_API_KEY = {file = config.age.secrets.openai-key.path;};
      FIRECRAWL_API_KEY = {file = config.age.secrets.firecrawl-api-key.path;};
      KIMI_API_KEY = {file = config.age.secrets.kimi-api-key.path;};
    })
    (makeAuthWrapper llm-agents.omp {
      # OPENROUTER_API_KEY = {file = config.age.secrets.openrouter-key.path;};
      KIMI_API_KEY = {file = config.age.secrets.kimi-api-key.path;};
    })
    (makeAuthWrapper mods {
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
    cc = "claude";
    wm = "workmux";
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
        uri = "git@git-ss.rudd-agama.ts.net:configs/oh-my-pi";
      };
    };
  };
}
