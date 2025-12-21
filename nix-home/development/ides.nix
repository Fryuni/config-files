{pkgs, ...}: {
  # home.packages = with pkgs; [
  #   # jetbrains.pycharm-professional
  #   # jetbrains.goland
  #   # jetbrains.rust-rover
  #   # jetbrains.webstorm
  #   # jetbrains.datagrip
  #   # jetbrains.idea-ultimate
  #   # android-studio
  # ];

  programs.zed-editor = {
    enable = true;
    package = pkgs.master.zed-editor;
    installRemoteServer = true;

    # Settings have to be editable, otherwise Zed won't allow selecting different models
    # from the UI.
    mutableUserSettings = true;
    mutableUserKeymaps = true;
    mutableUserTasks = false;
    mutableUserDebug = false;

    extensions = [
      "astro"
      "catppuccin"
      "catppuccin-icons"
      "cucumber"
      "git-firefly"
      "golangci-lint"
      "html"
      "nix"
      "php"
      "toml"
      "tsgo"
      "typespec"
      "zig"
    ];

    userKeymaps = [
      {
        context = "Editor && vim_mod == normal";
        bindings = {
          "space w" = "workspace::Save";
          "space l r" = "editor::Rename";
          "space g g" = [
            "task::Spawn"
            {
              task_name = "start lazygit";
              reveal_target = "center";
            }
          ];
        };
      }
    ];

    userTasks = [
      # {
      #   label = "start lazygit";
      #   command = "lazygit -p $ZED_WORKTREE_ROOT";
      # }
    ];

    userSettings = {
      vim_mode = true;
      relative_line_numbers = "enabled";
      ui_font_size = 16;
      buffer_font_size = 15;
      tab_size = 2;
      git_panel = {sort_by_path = false;};
      formatter = "auto";
      icon_theme = "Catppuccin Frappé";
      language_servers = ["!eslint" "!vtsls" "!typescript-language-server" "..."];
      format_on_save = "on";
      auto_update = false;
      restore_on_startup = "none";

      features = {
        edit_prediction_provider = "copilot";
      };
      prettier = {allowed = true;};

      theme = {
        mode = "system";
        light = "One Light";
        dark = "Catppuccin Macchiato";
      };

      agent = {
        always_allow_tool_actions = true;
        default_model = {
          provider = "copilot_chat";
          model = "gpt-5.2";
        };
        model_parameters = [];
      };
      agent_servers = {};
      context_servers = {};

      inlay_hints = {
        enabled = true;
        show_value_hints = true;
        show_type_hints = true;
        show_parameter_hints = true;
        show_other_hints = true;
        show_background = false;

        edit_debounce_ms = 700;
        scroll_debounce_ms = 50;
        toggle_on_modifiers_press = {
          control = false;
          alt = false;
          shift = false;
          platform = false;
          function = false;
        };
      };

      ssh_connections = [
        {
          host = "vps1.fryuni.dev";
          nickname = "VPS1";
          projects = [
            {paths = ["/root/services"];}
          ];
        }
      ];
    };
  };
}
