{pkgs, ...}: {
  imports = [
    # ./xfce.nix
    ./xsession.nix
    ./rofi.nix
    ./hyprland.nix
    ./gtk.nix
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

    master.zeal
  ];

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
}
