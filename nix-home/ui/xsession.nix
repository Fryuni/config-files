{
  config,
  lib,
  pkgs,
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

  modifier = "Mod4";
  terminal = lib.getExe pkgs.ghostty;
  flameshot = lib.getExe pkgs.flameshot;
  i3lock = lib.getExe pkgs.i3lock;
  rofi = lib.getExe config.programs.rofi.package;
  copyq = lib.getExe pkgs.copyq;
  brightnessctl = lib.getExe pkgs.brightnessctl;
  pamixer = lib.getExe pkgs.pamixer;
  playerctl = lib.getExe pkgs.playerctl;
  findCursor = "${lib.getExe pkgs.find-cursor} --size 280 --distance 35 --line-width 6 --color ${lib.escapeShellArg colors.primary} --repeat 2 --grow";
  workspaceOutputsConfig = "${config.xdg.cacheHome}/i3/workspace-outputs.conf";
  generateWorkspaceOutputs = pkgs.writeShellApplication {
    name = "generate-i3-workspace-outputs";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.xrandr
    ];
    text = ''
      output_file=${lib.escapeShellArg workspaceOutputsConfig}
      mkdir -p "$(dirname "$output_file")"

      mapfile -t outputs < <(
        xrandr --listactivemonitors |
          awk '
            /^Monitors:/ { next }
            NF && match($3, /([+-][0-9]+)([+-][0-9]+)$/, position) {
              printf "%d\t%d\t%s\n", position[1], position[2], $NF
            }
          ' |
          sort -n -k1,1 -k2,2 -k3,3 |
          cut -f3
      )

      temporary="$(mktemp "$output_file.XXXXXX")"
      trap 'rm -f "$temporary"' EXIT

      if (( ''${#outputs[@]} > 0 )); then
        for workspace in {1..10}; do
          output_index=$(((workspace - 1) % ''${#outputs[@]}))
          printf 'workspace %d output %s\n' "$workspace" "''${outputs[$output_index]}" >>"$temporary"
        done
      fi

      if [[ ! -e "$output_file" ]] || ! cmp -s "$temporary" "$output_file"; then
        mv "$temporary" "$output_file"
      fi

      printf '%s\n' "$output_file"
    '';
  };
  seedAutorandrProfiles = pkgs.writeShellApplication {
    name = "seed-autorandr-profiles";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      config_root="''${XDG_CONFIG_HOME:-$HOME/.config}/autorandr"
      mkdir -p "$config_root"

      for profile in docked mobile; do
        source="/etc/xdg/autorandr/$profile"
        destination="$config_root/$profile"
        if [[ -d "$source" && ! -e "$destination" && ! -L "$destination" ]]; then
          temporary="$(mktemp -d --tmpdir="$config_root" ".$profile.XXXXXX")"
          cp -R "$source/." "$temporary/"
          chmod -R u+rwX "$temporary"
          if ! mv -T "$temporary" "$destination" 2>/dev/null; then
            rm -rf "$temporary"
          fi
        fi
      done
    '';
  };
  configureDisplays = pkgs.writeShellApplication {
    name = "configure-displays";
    runtimeInputs = [
      pkgs.arandr
      pkgs.autorandr
      pkgs.zenity
    ];
    text = ''
      ${lib.getExe seedAutorandrProfiles}
      arandr

      config_root="''${XDG_CONFIG_HOME:-$HOME/.config}/autorandr"
      while profile="$(zenity --entry \
        --title="Save display profile" \
        --text="Enter a new profile name for this display layout:" \
        --ok-label="Save")"; do
        if [[ ! "$profile" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
          zenity --error --title="Invalid profile name" \
            --text="Use letters, numbers, dots, underscores, or hyphens; start with a letter or number."
          continue
        fi
        if [[ -e "$config_root/$profile" || -L "$config_root/$profile" ]]; then
          zenity --error --title="Profile already exists" \
            --text="The profile ‘$profile’ already exists. Choose a different name."
          continue
        fi
        if autorandr --save "$profile" --match-edid; then
          zenity --info --title="Display profile saved" \
            --text="Saved the current layout as ‘$profile’."
          exit 0
        fi
        zenity --error --title="Could not save profile" \
          --text="autorandr could not save ‘$profile’."
      done
    '';
  };
  selectDisplayProfile = pkgs.writeShellApplication {
    name = "select-display-profile";
    runtimeInputs = [
      pkgs.autorandr
      pkgs.zenity
    ];
    text = ''
      ${lib.getExe seedAutorandrProfiles}
      mapfile -t profiles < <(autorandr --detected --match-edid)
      if (( ''${#profiles[@]} == 0 )); then
        zenity --info --title="No matching display profiles" \
          --text="No saved profiles match the currently connected displays."
        exit 0
      fi

      profile="$(printf '%s\n' "''${profiles[@]}" | zenity --list \
        --title="Select display profile" \
        --text="Profiles matching the connected displays:" \
        --column="Profile" \
        --hide-header)" || exit 0
      [[ -n "$profile" ]] || exit 0

      if ! autorandr --load "$profile" --match-edid; then
        zenity --error --title="Could not load profile" \
          --text="autorandr could not load ‘$profile’."
        exit 1
      fi
    '';
  };
  configureDisplaysDesktop = pkgs.makeDesktopItem {
    name = "configure-displays";
    desktopName = "Configure Displays";
    comment = "Arrange displays and save an autorandr profile";
    exec = lib.getExe configureDisplays;
    icon = "preferences-desktop-display";
    categories = ["Settings" "HardwareSettings"];
  };
  selectDisplayProfileDesktop = pkgs.makeDesktopItem {
    name = "select-display-profile";
    desktopName = "Select Display Profile";
    comment = "Load a profile matching the connected displays";
    exec = lib.getExe selectDisplayProfile;
    icon = "video-display";
    categories = ["Settings" "HardwareSettings"];
  };
  openwhisprI3Autostart = pkgs.writeShellApplication {
    name = "openwhispr-i3-autostart";
    runtimeInputs = [pkgs.systemd];
    text = ''
      systemctl --user start ydotoold.service
      exec ${lib.getExe pkgs.openwhispr}
    '';
  };
  i3FocusAndCenter = pkgs.writeShellApplication {
    name = "i3-focus-and-center";
    runtimeInputs = [
      pkgs.i3
      pkgs.xdotool
    ];
    text = ''
      i3-msg focus "$1" >/dev/null

      window="$(xdotool getwindowfocus)"
      WIDTH=0
      HEIGHT=0
      eval "$(xdotool getwindowgeometry --shell "$window")"
      xdotool mousemove --sync --window "$window" "$((WIDTH / 2))" "$((HEIGHT / 2))"
    '';
  };
in {
  home.packages = [
    pkgs.autotiling
    pkgs.brightnessctl
    pkgs.copyq
    pkgs.dunst
    pkgs.flameshot
    pkgs.i3lock
    pkgs.networkmanagerapplet
    pkgs.pavucontrol
    pkgs.pamixer
    pkgs.playerctl
    configureDisplays
    selectDisplayProfile
    configureDisplaysDesktop
    selectDisplayProfileDesktop
  ];

  # Xorg derives 137 DPI from the combined displays; 96 DPI is 100% scale.
  xresources.properties."Xft.dpi" = 96;

  xsession = {
    enable = true;
    scriptPath = ".hm-xsession";

    windowManager.i3 = {
      enable = true;
      package = pkgs.i3;

      config = {
        inherit modifier terminal;

        fonts = {
          names = ["JetBrainsMono Nerd Font"];
          size = 16.0;
        };

        gaps = {
          inner = 3;
          outer = 6;
          smartBorders = "on";
        };

        floating = {
          inherit modifier;
          titlebar = false;
        };
        menu = "${rofi} -show drun";
        bars = [];

        startup = [
          {
            command = "xset r rate 200 30";
            always = true;
            notification = false;
          }
          {
            command = "${lib.getExe seedAutorandrProfiles} && ${lib.getExe pkgs.autorandr} --change --default horizontal --match-edid && ${lib.getExe pkgs.xrandr} --dpi 96 && ${pkgs.i3}/bin/i3-msg reload && ${pkgs.i3}/bin/i3-msg 'workspace number 1; workspace number 2; workspace number 1'";
            always = true;
            notification = false;
          }
          {
            command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
            always = true;
            notification = false;
          }
          {
            command = lib.getExe pkgs.autotiling;
            always = true;
            notification = false;
          }
          {
            command = lib.getExe openwhisprI3Autostart;
            notification = false;
          }
        ];

        keybindings = {
          # Core applications and session controls.
          "${modifier}+Return" = "exec ${terminal}";
          "${modifier}+Shift+Return" = "exec ${terminal} -e t";
          "${modifier}+q" = "kill";
          "${modifier}+m" = "exit";
          "${modifier}+n" = "exec thunar";
          "${modifier}+Shift+n" = "exec ${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          "${modifier}+d" = "exec ${rofi} -show drun";
          "${modifier}+space" = "exec vicinae toggle";
          "${modifier}+b" = "exec ${lib.getExe config.programs.chromium.package}";
          "${modifier}+Shift+b" = "exec ${lib.getExe pkgs.master.google-chrome}";

          # Window state. i3's global fullscreen is the closest X11 equivalent
          # to a maximized fullscreen window that remains above the bar.
          "${modifier}+f" = "fullscreen toggle";
          "${modifier}+Shift+f" = "fullscreen toggle global";
          "${modifier}+v" = "floating toggle";
          "${modifier}+p" = "sticky toggle";

          # Rofi and clipboard utilities.
          "${modifier}+c" = "exec ${rofi} -show calc -modi calc -no-show-match -no-sort";
          "${modifier}+x" = "exec ${rofi} -show power-menu -modi power-menu:rofi-power-menu";
          "${modifier}+z" = "exec ${rofi} -modi emoji -show emoji";
          "${modifier}+Shift+v" = "exec ${copyq} menu";

          # Native X11 Flameshot commands own the X clipboard directly.
          "Print" = "exec ${flameshot} gui";
          "Shift+Print" = "exec ${flameshot} full -c";
          "${modifier}+Print" = "exec ${flameshot} screen -c";
          "${modifier}+l" = "exec ${i3lock} -c 252a34";
          "${modifier}+Pause" = "exec --no-startup-id ${findCursor}";

          # Keep keyboard-driven focus and the pointer on the same window.
          "${modifier}+Left" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} left";
          "${modifier}+Right" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} right";
          "${modifier}+Up" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} up";
          "${modifier}+Down" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} down";
          "${modifier}+h" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} left";
          "${modifier}+j" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} down";
          "${modifier}+k" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} up";
          "${modifier}+semicolon" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} right";
          "${modifier}+Tab" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} next";
          "${modifier}+Shift+Tab" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} prev";

          # Move focused containers with arrows or the HJKL cluster.
          "${modifier}+Shift+Left" = "move left";
          "${modifier}+Shift+Right" = "move right";
          "${modifier}+Shift+Up" = "move up";
          "${modifier}+Shift+Down" = "move down";
          "${modifier}+Shift+h" = "move left";
          "${modifier}+Shift+j" = "move down";
          "${modifier}+Shift+k" = "move up";
          "${modifier}+Shift+l" = "move right";

          # Tiling, tabbed groups, and pseudotile's floating equivalent.
          "${modifier}+s" = "layout toggle split";
          "${modifier}+e" = "floating toggle";
          "${modifier}+g" = "layout tabbed";
          "${modifier}+w" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} next";
          "${modifier}+Shift+w" = "exec --no-startup-id ${lib.getExe i3FocusAndCenter} prev";

          # Workspaces and moving containers to them.
          "${modifier}+1" = "workspace number 1";
          "${modifier}+2" = "workspace number 2";
          "${modifier}+3" = "workspace number 3";
          "${modifier}+4" = "workspace number 4";
          "${modifier}+5" = "workspace number 5";
          "${modifier}+6" = "workspace number 6";
          "${modifier}+7" = "workspace number 7";
          "${modifier}+8" = "workspace number 8";
          "${modifier}+9" = "workspace number 9";
          "${modifier}+0" = "workspace number 10";
          "${modifier}+bracketleft" = "workspace prev";
          "${modifier}+bracketright" = "workspace next";
          "${modifier}+a" = "workspace back_and_forth";
          "${modifier}+Shift+1" = "move container to workspace number 1; workspace number 1";
          "${modifier}+Shift+2" = "move container to workspace number 2; workspace number 2";
          "${modifier}+Shift+3" = "move container to workspace number 3; workspace number 3";
          "${modifier}+Shift+4" = "move container to workspace number 4; workspace number 4";
          "${modifier}+Shift+5" = "move container to workspace number 5; workspace number 5";
          "${modifier}+Shift+6" = "move container to workspace number 6; workspace number 6";
          "${modifier}+Shift+7" = "move container to workspace number 7; workspace number 7";
          "${modifier}+Shift+8" = "move container to workspace number 8; workspace number 8";
          "${modifier}+Shift+9" = "move container to workspace number 9; workspace number 9";
          "${modifier}+Shift+0" = "move container to workspace number 10; workspace number 10";
          "${modifier}+Control+Shift+1" = "move container to workspace number 1";
          "${modifier}+Control+Shift+2" = "move container to workspace number 2";
          "${modifier}+Control+Shift+3" = "move container to workspace number 3";
          "${modifier}+Control+Shift+4" = "move container to workspace number 4";
          "${modifier}+Control+Shift+5" = "move container to workspace number 5";
          "${modifier}+Control+Shift+6" = "move container to workspace number 6";
          "${modifier}+Control+Shift+7" = "move container to workspace number 7";
          "${modifier}+Control+Shift+8" = "move container to workspace number 8";
          "${modifier}+Control+Shift+9" = "move container to workspace number 9";
          "${modifier}+Control+Shift+0" = "move container to workspace number 10";

          # Scratchpad and workspace cycling.
          "${modifier}+minus" = "scratchpad show";
          "${modifier}+Shift+minus" = "move scratchpad";
          "${modifier}+button4" = "workspace prev";
          "${modifier}+button5" = "workspace next";

          # Resize mode and direct resizing retain the directional bindings.
          "${modifier}+r" = "mode resize";
          "${modifier}+Control+Left" = "resize shrink width 20 px or 20 ppt";
          "${modifier}+Control+Right" = "resize grow width 20 px or 20 ppt";
          "${modifier}+Control+Up" = "resize shrink height 20 px or 20 ppt";
          "${modifier}+Control+Down" = "resize grow height 20 px or 20 ppt";
          "${modifier}+Control+h" = "resize shrink width 20 px or 20 ppt";
          "${modifier}+Control+l" = "resize grow width 20 px or 20 ppt";
          "${modifier}+Control+k" = "resize shrink height 20 px or 20 ppt";
          "${modifier}+Control+j" = "resize grow height 20 px or 20 ppt";

          # Hardware media and brightness keys.
          "XF86AudioRaiseVolume" = "exec ${pamixer} -i 5";
          "XF86AudioLowerVolume" = "exec ${pamixer} -d 5";
          "XF86AudioMute" = "exec ${pamixer} -t";
          "XF86AudioPlay" = "exec ${playerctl} play-pause";
          "XF86AudioPrev" = "exec ${playerctl} previous";
          "XF86AudioNext" = "exec ${playerctl} next";
          "XF86MonBrightnessUp" = "exec ${brightnessctl} set +5%";
          "XF86MonBrightnessDown" = "exec ${brightnessctl} set 5%-";
        };

        modes.resize = {
          Left = "resize shrink width 20 px or 20 ppt";
          Right = "resize grow width 20 px or 20 ppt";
          Up = "resize shrink height 20 px or 20 ppt";
          Down = "resize grow height 20 px or 20 ppt";
          h = "resize shrink width 20 px or 20 ppt";
          j = "resize grow height 20 px or 20 ppt";
          k = "resize shrink height 20 px or 20 ppt";
          l = "resize grow width 20 px or 20 ppt";
          Return = "mode default";
          Escape = "mode default";
        };

        colors = {
          focused = {
            text = colors.primary;
            background = colors.background-alt;
            border = colors.primary;
            childBorder = colors.primary;
            indicator = colors.alert;
          };
          focusedInactive = {
            text = colors.foreground;
            background = colors.background-alt;
            border = colors.background-alt;
            childBorder = colors.secondary;
            indicator = colors.alert;
          };
          unfocused = {
            text = colors.foreground;
            inherit (colors) background;
            border = colors.background;
            childBorder = colors.background;
            indicator = colors.alert;
          };
        };

        window = {
          border = 2;
          titlebar = false;
        };
      };

      extraConfig = ''
        include `${lib.getExe generateWorkspaceOutputs}`

        for_window [class="(?i)^(org\.pulseaudio\.pavucontrol|pavucontrol)$"] floating enable
        for_window [class="(?i)^nm-connection-editor$"] floating enable
        for_window [class="(?i)^bitwarden$"] floating enable
        for_window [class="(?i)^(org\.gnome\.Calculator|gnome-calculator)$"] floating enable
        for_window [class="(?i)^(org\.gnome\.Nautilus|nautilus)$" title="(?i).*properties.*"] floating enable
        for_window [title="(?i)^picture-in-picture$"] floating enable, sticky enable
        for_window [class="(?i)^flameshot$"] floating enable, sticky enable
        for_window [title="(?i)^flameshot(-pin)?$"] floating enable, sticky enable
        no_focus [class="open-whispr" title="Voice Recorder"]
        for_window [class="open-whispr" title="Voice Recorder"] floating enable, border none
      '';
    };
  };

  xdg.configFile."autorandr/postswitch.d/50-reload-i3-workspaces" = {
    source = pkgs.writeShellScript "reload-i3-workspaces" ''
      ${pkgs.i3}/bin/i3-msg reload >/dev/null 2>&1 || true
    '';
    executable = true;
  };

  services.copyq.enable = true;

  services.dunst = {
    enable = true;
    settings.global = {
      frame_color = colors.primary;
      separator_color = "frame";
    };
  };

  services.flameshot = {
    enable = true;
    package = pkgs.flameshot;
    settings.General = {
      showStartupLaunchMessage = false;
      useX11LegacyScreenshot = true;
    };
  };

  services.gnome-keyring = {
    enable = true;
    components = ["secrets"];
  };

  services.network-manager-applet.enable = true;

  services.picom = {
    enable = true;
    backend = "xrender";
    settings = {
      corner-radius = 4;
      round-borders = 1;
      # opacity-rule = [
      #   "80:!focused && !fullscreen && !I3_FLOATING_WINDOW@"
      # ];
      rounded-corners-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
      ];
    };
  };

  services.polybar = {
    enable = true;
    package = pkgs.polybar.override {
      i3Support = true;
      pulseSupport = true;
      iwSupport = true;
    };
    config = {
      "bar/main" = {
        width = "100%";
        height = 40;
        inherit (colors) background;
        inherit (colors) foreground;
        line-size = 2;
        line-color = colors.primary;
        border-size = 0;
        padding = 0;
        module-margin = 1;
        font-0 = "JetBrainsMono Nerd Font:style=Regular:size=14;4";
        modules-left = "i3";
        modules-center = "xwindow";
        modules-right = "pulseaudio wlan battery date";
        tray-position = "right";
        tray-padding = 2;
        enable-ipc = true;
      };

      "module/i3" = {
        type = "internal/i3";
        pin-workspaces = false;
        enable-click = true;
        enable-scroll = false;
        label-focused = "%index%";
        label-focused-foreground = colors.primary;
        label-focused-background = colors.background-alt;
        label-focused-underline = colors.primary;
        label-focused-padding = 2;
        label-unfocused = "%index%";
        label-unfocused-padding = 2;
        label-visible = "%index%";
        label-visible-padding = 2;
        label-urgent = "%index%";
        label-urgent-foreground = colors.alert;
        label-urgent-padding = 2;
      };

      "module/xwindow" = {
        type = "internal/xwindow";
        label = "%title:0:40:...%";
        format = "<label>";
        format-prefix = "  ";
        format-prefix-foreground = colors.primary;
        label-empty = "NixOS";
      };

      "module/pulseaudio" = {
        type = "internal/pulseaudio";
        format-volume = "<ramp-volume> <label-volume>";
        label-volume = "%percentage%%";
        label-muted = " muted";
        label-muted-foreground = colors.disabled;
        ramp-volume-0 = "";
        ramp-volume-1 = "";
        ramp-volume-2 = "";
      };

      "module/wlan" = {
        type = "internal/network";
        interface = "wlp61s0";
        interval = 5;
        format-connected = "<label-connected>";
        format-disconnected = "<label-disconnected>";
        label-connected = "%essid%";
        label-disconnected = "Disconnected";
        format-connected-prefix = "直 ";
        format-connected-prefix-foreground = colors.primary;
        format-disconnected-prefix = "睊 ";
        format-disconnected-foreground = colors.disabled;
        format-disconnected-prefix-foreground = colors.disabled;
      };

      "module/battery" = {
        type = "internal/battery";
        battery = "BAT0";
        adapter = "AC";
        label-charging = "%percentage%%";
        label-discharging = "%percentage%%";
        label-full = "%percentage%%";
        format-charging = "<label-charging>";
        format-discharging = "<label-discharging>";
        format-full = "<label-full>";
        format-charging-prefix = " ";
        format-discharging-prefix = " ";
        format-full-prefix = " ";
        format-charging-prefix-foreground = colors.primary;
        format-discharging-prefix-foreground = colors.foreground;
        format-full-prefix-foreground = colors.primary;
      };

      "module/date" = {
        type = "internal/date";
        interval = 1;
        date = "%Y-%m-%d %H:%M";
        label = "%date%";
        format = "<label>";
        format-prefix = "";
        format-foreground = colors.background;
        format-background = colors.primary;
        format-padding = 2;
      };

      settings = {
        screenchange-reload = true;
        pseudo-transparency = true;
      };
    };
    script = ''
      polybar --reload main &
    '';
  };

  systemd.user.services = {
    copyq = {
      Unit.PartOf = lib.mkForce ["hm-graphical-session.target"];
      Install.WantedBy = lib.mkForce ["hm-graphical-session.target"];
    };

    dunst = {
      Unit.PartOf = lib.mkForce ["hm-graphical-session.target"];
      Install.WantedBy = lib.mkForce ["hm-graphical-session.target"];
    };

    flameshot = {
      Unit.PartOf = lib.mkForce ["hm-graphical-session.target"];
      Install.WantedBy = lib.mkForce ["hm-graphical-session.target"];
    };

    network-manager-applet = {
      Unit.PartOf = lib.mkForce ["hm-graphical-session.target"];
      Install.WantedBy = lib.mkForce ["hm-graphical-session.target"];
    };

    picom = {
      Unit.PartOf = lib.mkForce ["hm-graphical-session.target"];
      Install.WantedBy = lib.mkForce ["hm-graphical-session.target"];
    };

    polybar = {
      Unit.PartOf = lib.mkForce ["hm-graphical-session.target"];
      Install.WantedBy = lib.mkForce ["hm-graphical-session.target"];
    };

    ydotoold = {
      Unit = {
        Description = "ydotool daemon";
        Documentation = "man:ydotoold(8)";
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.ydotool}/bin/ydotoold";
        Restart = "on-failure";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
