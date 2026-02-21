{pkgs, ...}: {
  imports = [
    # ./xfce.nix
    ./xsession.nix
    ./rofi.nix
    ./hyprland.nix
    ./gtk.nix
  ];

  home.packages = with pkgs; [
    calibre
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
