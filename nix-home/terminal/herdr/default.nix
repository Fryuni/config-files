{
  lib,
  pkgs,
  inputs,
  ...
}: let
  plugins = import ./plugins {inherit pkgs inputs;};
  treehousePlugin = plugins.herdr-treehouse;
  treehouseManifest = builtins.fromTOML (builtins.readFile "${inputs.herdr-treehouse}/herdr-plugin.toml");
  python = lib.getExe pkgs.python3;
  runtimeCommand = command:
    if builtins.head command == "python3"
    then [python] ++ builtins.tail command
    else command;
  registryEntry =
    (builtins.removeAttrs treehouseManifest ["id"])
    // {
      plugin_id = treehouseManifest.id;
      manifest_path = "${treehousePlugin}/herdr-plugin.toml";
      plugin_root = "${treehousePlugin}";
      enabled = true;
      source.kind = "local";
      startup = map (entry: entry // {command = runtimeCommand entry.command;}) treehouseManifest.startup;
      events = map (entry: entry // {command = runtimeCommand entry.command;}) treehouseManifest.events;
      panes = map (entry: entry // {command = runtimeCommand entry.command;}) treehouseManifest.panes;
    };
  toml = pkgs.formats.toml {};
  json = pkgs.formats.json {};
in {
  config = lib.mkIf (pkgs.stdenv.buildPlatform.system == pkgs.stdenv.hostPlatform.system) {
    home.packages = [pkgs.llm-agents.herdr];

    xdg.configFile = {
      "herdr/config.toml".source = toml.generate "herdr-config.toml" {
        onboarding = false;

        theme.name = "vesper";
        terminal.new_cwd = "follow";

        keys = {
          new_workspace = "";
          new_worktree = "prefix+shift+w";
          remove_worktree = "prefix+ctrl+d";
          rename_workspace = "prefix+ctrl+w";
          rename_tab = "prefix+ctrl+t";
          command = [
            {
              key = "prefix+shift+n";
              type = "shell";
              command = ''"$HERDR_BIN_PATH" workspace create --cwd "$HOME" --focus'';
              description = "new workspace at home";
            }
            {
              key = "prefix+shift+b";
              type = "shell";
              command = ''"$HERDR_BIN_PATH" plugin pane open --plugin local.herdr-treehouse --entrypoint branch-worktree --focus'';
              description = "open Treehouse branch workspace";
            }
            {
              key = "prefix+alt+g";
              type = "pane";
              command = "lazygit";
            }
          ];
        };

        ui = {
          show_agent_labels_on_pane_borders = true;
          agent_panel_sort = "priority";
          toast.delivery = "terminal";
          sound.enabled = true;
        };

        experimental.pane_history = false;
      };

      "herdr/plugins.json".source = json.generate "herdr-plugins.json" [registryEntry];
      "herdr/plugins/herdr-treehouse".source = treehousePlugin;
    };
  };
}
