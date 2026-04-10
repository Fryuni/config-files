{
  pkgs,
  inputs,
  ...
}: let
  colors = {
    background = "#252a34";
    background-alt = "#3b4354";
    foreground = "#F1FAEE";
    primary = "#08D9D6";
    secondary = "#047672";
    alert = "#ff2e63";
    disabled = "#707880";
  };

  inherit (pkgs.stdenv.hostPlatform) system;

  vicinae = inputs.vicinae.packages.${system}.default;

  # Vicinae extensions from the official store, built via Nix.
  # Available extensions can be listed with:
  #   nix flake show github:vicinaehq/extensions
  vicinaeExtensions = inputs.vicinae-extensions.packages.${system};

  extensions = [
    vicinaeExtensions.aria2-manager
    vicinaeExtensions.dashboard-icons
    vicinaeExtensions.hypr-keybinds
    vicinaeExtensions.hyprland-monitors
    vicinaeExtensions.it-tools
    vicinaeExtensions.nerdfont-search
    vicinaeExtensions.nix
    vicinaeExtensions.port-killer
    # vicinaeExtensions.systemd  # currently fails to build in nixpkgs (node-gyp)
  ];
  # Raycast-compatible extensions are installed via the store UI.
  # They are not built with Nix and live in ~/.local/share/vicinae/extensions/.
in {
  home.packages = [
    vicinae
  ];

  # Install extensions and theme as symlinks in the data directory
  xdg.dataFile =
    builtins.listToAttrs
    (builtins.map (ext: {
        name = "vicinae/extensions/${ext.name}";
        value.source = ext;
      })
      extensions)
    // {
      "vicinae/themes/lotus.toml".source = (pkgs.formats.toml {}).generate "lotus-theme" {
        meta = {
          version = 1;
          name = "Lotus";
          description = "Custom theme matching lotus-notebook color scheme";
          variant = "dark";
          inherits = "vicinae-dark";
        };

        colors = {
          core = {
            inherit (colors) background;
            inherit (colors) foreground;
            secondary_background = "#1e2230";
            border = colors.background-alt;
            accent = colors.primary;
          };

          accents = {
            blue = colors.primary;
            green = "#9ECE6A";
            magenta = "#F5C2E7";
            orange = "#FAB387";
            purple = "#CBA6F7";
            red = colors.alert;
            yellow = "#F9E2AF";
            cyan = colors.secondary;
          };

          list.item.selection = {
            background = colors.background-alt;
            secondary_background = "#444b5c";
          };
        };
      };
    };

  # Vicinae configuration
  xdg.configFile."vicinae/nix.json".text = builtins.toJSON {
    telemetry = {
      system_info = false;
    };

    search_files_in_root = false;
    close_on_focus_loss = true;
    pop_to_root_on_close = true;
    escape_key_behavior = "navigate_back";
    pop_on_backspace = true;
    favicon_service = "twenty";

    font = {
      rendering = "qt";
      normal = {
        family = "JetBrainsMono Nerd Font";
        size = 11;
      };
    };

    theme = {
      light = {
        name = "lotus";
        icon_theme = "auto";
      };
      dark = {
        name = "lotus";
        icon_theme = "auto";
      };
    };

    launcher_window = {
      opacity = 1.0;

      blur = {
        enabled = false;
      };

      dim_around = false;

      client_side_decorations = {
        enabled = true;
        rounding = 10;
        border_width = 1;
      };

      compact_mode = {
        enabled = false;
      };

      size = {
        width = 770;
        height = 480;
      };

      # Layer shell for Wayland/Hyprland
      layer_shell = {
        enabled = true;
        keyboard_interactivity = "on_demand";
        layer = "top";
      };
    };

    keybinds = {
      open-search-filter = "control+P";
      open-settings = "control+,";
      toggle-action-panel = "control+B";
      "action.copy" = "control+shift+C";
      "action.refresh" = "control+R";
    };

    favorites = [
      "clipboard:history"
    ];

    fallbacks = [
      "files:search"
    ];
  };

  # Systemd user service for Vicinae server daemon
  systemd.user.services.vicinae = {
    Unit = {
      Description = "Vicinae Launcher Daemon";
      Documentation = ["https://docs.vicinae.com"];
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      Type = "simple";
      ExecStart = "${vicinae}/bin/vicinae server --replace";
      Environment = [
        "VICINAE_OVERRIDES=%h/.config/vicinae/nix.json"
      ];
      Restart = "always";
      RestartSec = 5;
      KillMode = "process";
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
