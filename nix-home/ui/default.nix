{pkgs, ...}: {
  imports = [
    # ./xfce.nix
    ./xsession.nix
    ./rofi.nix
    ./hyprland.nix
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
    spotify
    discord-canary
    master.obsidian
    (jrnl.overrideAttrs (_: {doTest = false;}))
    vlc
    screenkey
    openwhispr

    master.zeal
  ];

  home.file.".background-image".source = ../../common/wallpaper/wallpaper.png;
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

  # Place mpv desktop entry directly in ~/.local/share/applications/
  # so KDE's ksycoca can index it under Hyprland (nix-profile symlinks
  # with epoch timestamps aren't reliably indexed by kbuildsycoca6)
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
  };

  programs.chromium = {
    enable = true;
    package = pkgs.master.google-chrome;
    extensions = builtins.map (id: {inherit id;}) [
      # LastPass
      "hdokiejnpimakedhajhdlcegeplioahd"
      # Dark Reader
      "eimadpbcbfnmbkopoojfekhnkhdbieeh"
    ];
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
