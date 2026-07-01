{
  lib,
  pkgs,
  ...
}: let
  t3CodePackage = pkgs.symlinkJoin {
    name = "t3code-telemetry-disabled";
    paths = [pkgs.t3code];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram "$out/bin/t3code" \
        --set T3CODE_TELEMETRY_ENABLED false
      wrapProgram "$out/bin/t3code-desktop" \
        --set T3CODE_TELEMETRY_ENABLED false
    '';
  };

  t3ServerSettings = {
    enableAssistantStreaming = true;
    defaultThreadEnvMode = "local";
    providers = {
      codex = {
        enabled = true;
        binaryPath = "${pkgs.codex}/bin/codex";
      };
      opencode = {
        enabled = true;
        binaryPath = "${pkgs.llm-agents.opencode}/bin/opencode";
      };
      claudeAgent.enabled = false;
      cursor.enabled = false;
    };
    textGenerationModelSelection = {
      instanceId = "opencode";
      model = "openai/gpt-5";
    };
  };

  managedSettings = pkgs.writeText "t3-code-managed-settings.json" (builtins.toJSON t3ServerSettings);
in
  lib.mkIf (pkgs.stdenv.buildPlatform.system == pkgs.stdenv.hostPlatform.system) {
    home.packages = [
      t3CodePackage
      pkgs.codex
      pkgs.llm-agents.opencode
    ];

    home.activation.mergeT3CodeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      t3_userdata="$HOME/.t3/userdata"
      t3_settings="$t3_userdata/settings.json"

      ${pkgs.coreutils}/bin/mkdir -p "$t3_userdata"
      t3_next="$(${pkgs.coreutils}/bin/mktemp "$t3_userdata/settings.json.XXXXXX")"
      if [ ! -e "$t3_settings" ]; then
        printf '{}' > "$t3_settings"
      fi
      ${pkgs.coreutils}/bin/chmod u+w "$t3_settings"

      ${pkgs.jq}/bin/jq -S -s '.[0] * .[1]' "$t3_settings" ${managedSettings} > "$t3_next"
      ${pkgs.coreutils}/bin/cat "$t3_next" > "$t3_settings"
      ${pkgs.coreutils}/bin/rm -f "$t3_next"
      ${pkgs.coreutils}/bin/chmod u+w "$t3_settings"
    '';
  }
