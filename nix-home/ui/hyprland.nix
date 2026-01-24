{
  config,
  pkgs,
  lib,
  ...
}: let
  colors = {
    background = "252a34";
    background-alt = "3b4354";
    foreground = "F1FAEE";
    primary = "08D9D6";
    secondary = "047672";
    alert = "ff2e63";
    disabled = "707880";
  };
in {
  home.packages = with pkgs; [
    # Clipboard
    wl-clipboard
    cliphist

    # Notifications
    libnotify

    # Screen locker
    swaylock-effects
    swayidle

    # Brightness/Volume control
    brightnessctl
    playerctl
    pamixer

    # Screenshot (grim required for flameshot wayland adapter)
    grim

    # Wallpaper daemon
    swww
  ];

  # Hyprland configuration
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    systemd.enable = true;

    plugins = with pkgs.hyprlandPlugins; [
      hyprexpo # Workspace overview
      borders-plus-plus # Enhanced borders
    ];

    settings = {
      # Monitor configuration
      # Use `hyprctl monitors` to find your monitor names
      monitor = [
        # Default: auto-detect
        ",preferred,auto,1"
      ];

      # Execute on startup
      exec-once = [
        # Polkit agent
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"

        # Clipboard manager
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"

        # Wallpaper daemon
        # "swww-daemon"
        # "swww img ${../../common/wallpaper/wallpaper.png}"

        # Notification daemon
        "swaync"
      ];

      # General settings
      general = {
        gaps_in = 3;
        gaps_out = 6;
        border_size = 2;
        "col.active_border" = "rgba(${colors.primary}ee) rgba(${colors.secondary}ee) 45deg";
        "col.inactive_border" = "rgba(${colors.background-alt}aa)";
        layout = "dwindle"; # Smart autotiling layout
        allow_tearing = false;
      };

      # Input settings
      input = {
        kb_layout = "us";
        kb_variant = "intl"; # US International with dead keys
        kb_options = "";
        kb_model = "";
        kb_rules = "";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          tap-to-click = true;
        };
      };

      # Decoration
      decoration = {
        rounding = 4;
        blur = {
          enabled = false;
          size = 8;
          passes = 2;
          new_optimizations = true;
          xray = false;
        };
        shadow = {
          enabled = false;
          range = 15;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
      };

      # Animations
      animations = {
        enabled = false;
        bezier = [
          "ease, 0.25, 0.1, 0.25, 1"
          "wind, 0.05, 0.9, 0.1, 1.05"
        ];
        animation = [
          "windows, 1, 4, wind, slide"
          "windowsIn, 1, 4, wind, slide"
          "windowsOut, 1, 4, wind, slide"
          "windowsMove, 1, 4, wind, slide"
          "border, 1, 5, default"
          "fade, 1, 5, ease"
          "workspaces, 1, 5, wind"
        ];
      };

      # Dwindle layout - smart autotiling
      dwindle = {
        pseudotile = true; # Respect window size hints
        preserve_split = true; # Keep split direction on resize
        smart_split = false; # Disable cursor-based splitting
        smart_resizing = true; # Resize affects neighbors smartly
        force_split = 2; # 2=default split (right/bottom based on aspect ratio)
      };

      # Master layout (alternative)
      master = {
        new_status = "slave";
        mfact = 0.55; # Master takes 55% of screen
      };

      # Group (tabbed windows) settings
      group = {
        "col.border_active" = "rgba(${colors.primary}ff)";
        "col.border_inactive" = "rgba(${colors.background-alt}aa)";
        groupbar = {
          enabled = true;
          height = 20;
          font_size = 12;
          "col.active" = "rgba(${colors.primary}ff)";
          "col.inactive" = "rgba(${colors.background-alt}ff)";
        };
      };

      # Plugin configurations
      plugin = {
        # hyprexpo - Workspace overview
        hyprexpo = {
          columns = 3;
          gap_size = 5;
          bg_col = "rgba(${colors.background}ff)";
          workspace_method = "first 1"; # Start from workspace 1
          enable_gesture = true;
        };

        # borders-plus-plus - Enhanced borders
        "borders-plus-plus" = {
          add_borders = 1;
          "col.border_1" = "rgba(${colors.secondary}aa)";
          border_size_1 = 1;
          natural_rounding = true;
        };
      };

      # Misc
      misc = {
        force_default_wallpaper = 1;
        disable_hyprland_logo = false;
        disable_splash_rendering = false;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
      };

      # Keybindings
      "$mod" = "SUPER";
      "$terminal" = "ghostty -e t";
      "$menu" = "rofi -show drun";
      "$browser" = "google-chrome-stable";

      bind = [
        # ===== Core Bindings =====
        "$mod, Return, exec, $terminal"
        "$mod, Q, killactive"
        "$mod, M, exit"
        "$mod, N, exec, thunar"
        "$mod, D, exec, $menu"
        "$mod, B, exec, $browser"

        # ===== Window State =====
        "$mod, F, fullscreen, 0" # True fullscreen
        "$mod SHIFT, F, fullscreen, 1" # Maximize (keep gaps/bar)
        "$mod, V, togglefloating"
        "$mod, P, pin" # Pin floating window

        # ===== Rofi Utilities =====
        "$mod, C, exec, rofi -show calc -modi calc -no-show-match -no-sort"
        "$mod, X, exec, rofi -show power-menu -modi power-menu:rofi-power-menu"
        "$mod, Z, exec, rofi -modi emoji -show emoji"
        "$mod SHIFT, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"

        # ===== Screenshot (Flameshot) =====
        ", Print, exec, flameshot gui"
        "SHIFT, Print, exec, flameshot full"
        "$mod, Print, exec, flameshot screen"

        # ===== Screen Lock =====
        "$mod, L, exec, swaylock"

        # ===== Focus Navigation =====
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod, h, movefocus, l"
        "$mod, l, movefocus, r"
        "$mod, k, movefocus, u"
        "$mod, j, movefocus, d"

        # Cycle through windows
        "$mod, Tab, cyclenext"
        "$mod SHIFT, Tab, cyclenext, prev"

        # ===== Move Windows =====
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"
        "$mod SHIFT, h, movewindow, l"
        "$mod SHIFT, l, movewindow, r"
        "$mod SHIFT, k, movewindow, u"
        "$mod SHIFT, j, movewindow, d"

        # ===== Layout Control (Dwindle) =====
        "$mod, s, togglesplit" # Toggle split direction
        "$mod, e, pseudo" # Toggle pseudotile (respect window size)
        "$mod, g, togglegroup" # Group windows (tabs)
        "$mod, w, changegroupactive, f" # Next tab in group
        "$mod SHIFT, w, changegroupactive, b" # Previous tab in group

        # Swap with master/first
        "$mod, m, layoutmsg, swapwithmaster"

        # ===== Workspace Navigation =====
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Previous/Next workspace
        "$mod, bracketleft, workspace, e-1"
        "$mod, bracketright, workspace, e+1"
        "$mod, a, workspace, previous" # Alt-tab style for workspaces

        # ===== Move Window to Workspace =====
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # ===== Scratchpad (Special Workspace) =====
        "$mod, minus, togglespecialworkspace, magic"
        "$mod SHIFT, minus, movetoworkspace, special:magic"

        # ===== Workspace Overview (hyprexpo) =====
        "$mod, grave, hyprexpo:expo, toggle" # ` key

        # ===== Scroll Through Workspaces =====
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"

        # ===== Resize Mode =====
        "$mod, r, submap, resize"
      ];

      # Resize bindings (repeatable)
      binde = [
        "$mod CTRL, left, resizeactive, -20 0"
        "$mod CTRL, right, resizeactive, 20 0"
        "$mod CTRL, up, resizeactive, 0 -20"
        "$mod CTRL, down, resizeactive, 0 20"
        "$mod CTRL, h, resizeactive, -20 0"
        "$mod CTRL, l, resizeactive, 20 0"
        "$mod CTRL, k, resizeactive, 0 -20"
        "$mod CTRL, j, resizeactive, 0 20"
      ];

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Media keys (works even when locked)
      bindel = [
        ", XF86AudioRaiseVolume, exec, pamixer -i 5"
        ", XF86AudioLowerVolume, exec, pamixer -d 5"
        ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      bindl = [
        ", XF86AudioMute, exec, pamixer -t"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioNext, exec, playerctl next"
      ];

      debug = {
        disable_logs = false;
      };

      # Window rules
      windowrulev2 = let
        buildRules = builtins.concatMap (
          group: let
            base = builtins.head group;
            rules = builtins.tail group;
          in
            map (rule: "${rule}, ${base}") rules
        );
      in
        buildRules [
          ["title:.*" "bordercolor rgb(FF00FF)"]
          ["class:^(pavucontrol)$" "float"]
          ["class:^(nm-connection-editor)$" "float"]
          ["title:^(Picture-in-Picture)$" "float"]
          ["title:(Bitwarden)" "float"]
          ["class:^(org.gnome.Calculator)$" "float"]
          ["class:^(org.gnome.Nautilus)$, title:^(Properties)$" "float"]
          ["title:^(Picture-in-Picture)$" "pin"]

          ["initialTitle:(flameshot)" "monitor 0" "move 0 0" "float" "pin" "noanim" "stayfocused" "size 5760 2160" "bordercolor rgb(FF0000)"]

          # Suppress maximize requests from apps
          # ["class:.*" "suppressevent maximize"]
        ];
    };

    # Resize submap (modal resize mode)
    extraConfig = ''
      # Resize submap
      submap = resize
      binde = , left, resizeactive, -20 0
      binde = , right, resizeactive, 20 0
      binde = , up, resizeactive, 0 -20
      binde = , down, resizeactive, 0 20
      binde = , h, resizeactive, -20 0
      binde = , l, resizeactive, 20 0
      binde = , k, resizeactive, 0 -20
      binde = , j, resizeactive, 0 20
      bind = , Return, submap, reset
      bind = , Escape, submap, reset
      submap = reset
    '';
  };

  # Waybar status bar
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 36;
        spacing = 4;

        modules-left = ["hyprland/workspaces" "hyprland/window"];
        modules-center = ["pulseaudio" "tray" "battery"];
        modules-right = ["network" "clock"];

        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
            "10" = "0";
            urgent = "U";
            default = "D";
          };
          on-click = "activate";
        };

        "hyprland/window" = {
          max-length = 50;
          separate-outputs = true;
        };

        clock = {
          format = "  {:%Y-%m-%d  %H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        # cpu = {
        #   format = " {usage}%";
        #   tooltip = false;
        # };

        # memory = {
        #   format = " {}%";
        # };

        # battery = {
        #   states = {
        #     warning = 30;
        #     critical = 15;
        #   };
        #   format = "{icon} {capacity}%";
        #   format-charging = " {capacity}%";
        #   format-icons = ["" "" "" "" ""];
        # };

        network = {
          format-wifi = "  {signalStrength}%";
          format-ethernet = " Connected";
          format-disconnected = "睊 Disconnected";
          tooltip-format = "{ifname}: {ipaddr}";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = " Muted";
          # format-icons = {
          #   default = ["" "" ""];
          # };
          on-click = "pavucontrol";
        };

        tray = {
          spacing = 10;
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 14px;
      }

      window#waybar {
        background-color: rgba(37, 42, 52, 0.9);
        color: #${colors.foreground};
        border-bottom: 2px solid #${colors.primary};
      }

      #workspaces button {
        padding: 0 8px;
        color: #${colors.disabled};
        background-color: transparent;
        border-radius: 0;
      }

      #workspaces button.active {
        color: #${colors.primary};
        background-color: #${colors.background-alt};
        border-bottom: 2px solid #${colors.primary};
      }

      #workspaces button.urgent {
        color: #${colors.alert};
      }

      #clock,
      #battery,
      #cpu,
      #memory,
      #network,
      #pulseaudio,
      #tray {
        padding: 0 12px;
      }

      #clock {
        background-color: #${colors.primary};
        color: #${colors.background};
        border-radius: 0;
        padding: 0 16px;
      }

      #battery.warning {
        color: #f9e2af;
      }

      #battery.critical {
        color: #${colors.alert};
      }

      #network.disconnected {
        color: #${colors.disabled};
      }

      #pulseaudio.muted {
        color: #${colors.disabled};
      }
    '';
  };

  # SwayNotificationCenter
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-margin-top = 10;
      control-center-margin-right = 10;
      notification-icon-size = 64;
      notification-body-image-height = 100;
      notification-body-image-width = 200;
      timeout = 10;
      timeout-low = 5;
      timeout-critical = 0;
      fit-to-screen = true;
      control-center-width = 500;
      notification-window-width = 400;
    };
  };

  # Swaylock configuration
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      color = colors.background;
      font = "JetBrainsMono Nerd Font";
      show-failed-attempts = true;
      ignore-empty-password = true;
      indicator-radius = 100;
      indicator-thickness = 10;
      line-color = colors.background;
      ring-color = colors.primary;
      inside-color = colors.background;
      key-hl-color = colors.primary;
      separator-color = "00000000";
      text-color = colors.foreground;
      text-ver-color = colors.primary;
      ring-ver-color = colors.secondary;
      inside-ver-color = colors.background;
      text-wrong-color = colors.alert;
      ring-wrong-color = colors.alert;
      inside-wrong-color = colors.background;
      bs-hl-color = colors.alert;
      grace = 2;
      grace-no-mouse = true;
      grace-no-touch = true;
      clock = true;
      indicator = true;
      effect-blur = "7x5";
      effect-vignette = "0.5:0.5";
      screenshots = true;
    };
  };

  # Flameshot screenshot tool with Wayland/grim support
  services.flameshot = {
    enable = true;
    settings = {
      General = {
        # Use grim adapter for Wayland compatibility (required for Hyprland)
        useGrimAdapter = true;
        # Suppress the grim warning since we're explicitly enabling it
        disabledGrimWarning = true;
        showStartupLaunchMessage = false;
      };
    };
  };
}
