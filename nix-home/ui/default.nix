{
  lib,
  pkgs,
  ...
}: let
  setRandomWallpaper = pkgs.writeShellScript "set-random-wallpaper" ''
    set -euo pipefail

    wallpaper_directory="${../../common/wallpaper}"

    mapfile -t outputs < <(
      ${pkgs.xrandr}/bin/xrandr --listactivemonitors |
        ${pkgs.gawk}/bin/awk '
          /^Monitors:/ { found_header = 1; next }
          found_header && NF { print $NF }
        '
    )
    if [ "''${#outputs[@]}" -eq 0 ]; then
      echo "No active outputs found." >&2
      exit 1
    fi

    mapfile -d "" -t wallpapers < <(
      ${pkgs.findutils}/bin/find "$wallpaper_directory" -type f -print0 |
        ${pkgs.coreutils}/bin/shuf -z -n "''${#outputs[@]}"
    )
    if [ "''${#wallpapers[@]}" -lt "''${#outputs[@]}" ]; then
      echo "Not enough wallpaper files in $wallpaper_directory: need ''${#outputs[@]}, found ''${#wallpapers[@]}." >&2
      exit 1
    fi

    arguments=()
    for index in "''${!outputs[@]}"; do
      arguments+=(--output "''${outputs[$index]}" --zoom "''${wallpapers[$index]}")
    done

    exec ${pkgs.xwallpaper}/bin/xwallpaper "''${arguments[@]}"
  '';
in {
  imports = [
    # ./xfce.nix
    ./xsession.nix
    ./rofi.nix
    ./plasma.nix
    ./vicinae.nix
    ./gtk.nix
    ./fonts.nix
    ./alacritty.nix
    ./ghostty.nix
  ];

  home.packages = with pkgs; [
    stable.calibre
    kdePackages.okular
    kdePackages.gwenview
    spotify
    stable.discord
    master.obsidian
    (jrnl.overrideAttrs (_: {doTest = false;}))
    vlc
    screenkey
    openwhispr

    master.zeal
    (lib.lowPrio slack)
    (lib.hiPrio slack-cli)
    insomnia
    dbeaver-bin
  ];

  services.random-background = {
    enable = true;
    imageDirectory = "${../../common/wallpaper}";
    interval = "30min";
    display = "fill";
    enableXinerama = true;
  };

  systemd.user.services.random-background.Service.ExecStart = lib.mkForce setRandomWallpaper;

  xdg.enable = true;

  programs.mpv = {
    enable = true;
    config = {
      alang = "jpn,eng";
      slang = "jpn,eng";
      audio-channels = "stereo";
      ytdl-format = "bestvideo[height<=?1440]+bestaudio/best";
    };
  };

  # Place mpv's desktop entry directly in ~/.local/share/applications/
  # so the active desktop's application cache indexes it reliably rather
  # than relying on profile symlinks with epoch timestamps.
  xdg.dataFile."applications/mpv.desktop".text = builtins.readFile "${pkgs.mpv}/share/applications/mpv.desktop";

  # Thunar "Open Terminal Here" uses exo-open which reads this config
  xdg.configFile."xfce4/helpers.rc".text = ''
    TerminalEmulator=custom-TerminalEmulator
    TerminalEmulatorCustom=${pkgs.ghostty}/bin/ghostty
  '';

  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps = import ./xdg-mime.nix {
    defaultBrowser = "firefox-beta.desktop";
    defaultVideo = "mpv.desktop";
    defaultImage = "org.kde.gwenview.desktop";
  };

  programs.chromium = {
    enable = true;
    package = pkgs.master.google-chrome;
  };

  programs.firefox = {
    enable = true;
    package = pkgs.stable.firefox-beta;
  };

  # Autostart OpenWhispr on login (XDG autostart for Plasma/X11 and any XDG-compliant DE)
  xdg.configFile."autostart/openwhispr.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=OpenWhispr
    Comment=Voice-to-text dictation
    Exec=${pkgs.lib.meta.getExe pkgs.openwhispr}
    Terminal=false
    StartupNotify=false
    X-GNOME-Autostart-enabled=true
  '';
}
