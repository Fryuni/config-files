{pkgs, ...}: {
  imports = [
    # ./xfce.nix
    ./xsession.nix
  ];

  home.packages = with pkgs; [
    rofi
    calibre
    spotify
    flameshot
    discord-canary
    obsidian
    vlc
    stremio
    screenkey
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
    defaultBrowser = "google-chrome-beta.desktop";
    defaultVideo = "mpv.desktop";
  };

  programs.chromium = {
    enable = true;
    package = pkgs.master.google-chrome-beta;
    extensions = builtins.map (id: {inherit id;}) [
      "eimadpbcbfnmbkopoojfekhnkhdbieeh"
    ];
  };

  programs.firefox = {
    enable = true;
    package = pkgs.firefox-beta-bin;
  };
}
