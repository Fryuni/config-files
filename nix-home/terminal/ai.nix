{
  pkgs,
  config,
  ...
}: let
  makeAuthWrapper = pkg: envMap:
    pkgs.symlinkJoin {
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
    };
in {
  home.packages = with pkgs; [
    (makeAuthWrapper llm-agents.crush {
      VERTEXAI_LOCATION = "global";
      VERTEXAI_PROJECT = "croct-dev";
      GOOGLE_APPLICATION_CREDENTIALS = config.age.secrets.google-account.path;
    })
    (makeAuthWrapper master.opencode {
      VERTEX_LOCATION = "global";
      GOOGLE_CLOUD_PROJECT = "croct-dev";
      GOOGLE_APPLICATION_CREDENTIALS = config.age.secrets.google-account.path;
    })
    (makeAuthWrapper nur.repos.charmbracelet.mods {
      OPENAI_API_KEY = {file = config.age.secrets.openai-key.path;};
    })
    (makeAuthWrapper oh-my-opencode {
      VERTEX_LOCATION = "global";
      GOOGLE_CLOUD_PROJECT = "croct-dev";
      GOOGLE_APPLICATION_CREDENTIALS = config.age.secrets.google-account.path;
    })

    # AI auxiliary tools
    mcp-grafana
    rustCrates.skill-manager
  ];

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
}
