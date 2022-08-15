{ pkgs, ... }:
{
  home.packages = with pkgs; [
    calibre
    flameshot
    sublime4
    discord-canary
    dbeaver
    vlc
    jetbrains.pycharm-professional
    jetbrains.goland
    jetbrains.webstorm
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

  xdg.desktopEntries = {
    "discord" = {
      name = "Discord";
      exec = "nowl ${pkgs.discord-canary}/bin/discord";
      terminal = false;
      categories = [ "Application" "Network" ];
    };
  };
  xdg.mimeApps = import ./xdg-mime.nix {
    defaultBrowser = "firefox.desktop";
    defaultVideo = "mpv.desktop";
  };

  programs.chromium = {
    enable = true;
    package = pkgs.google-chrome-beta;
    extensions = builtins.map (id: { inherit id; }) [
      "eimadpbcbfnmbkopoojfekhnkhdbieeh"
    ];
  };

  programs.firefox = {
    enable = true;
    package = pkgs.firefox-beta-bin;
    ## Extensions don't seem to be working
    # extensions = with pkgs; [
    #   (fetchFirefoxAddon {
    #     name = "lastpass";
    #     url = "https://addons.mozilla.org/firefox/downloads/file/3984651/lastpass_password_manager-4.101.0.2.xpi";
    #     sha256 = "sha256-RClMHLcRpdVmoX3mCH5IJXVegZRHNebxgt5M+dY+jPw=";
    #   })
    #   (fetchFirefoxAddon {
    #     name = "dark-reader";
    #     url = "https://addons.mozilla.org/firefox/downloads/file/3987418/darkreader-4.9.55.xpi";
    #     sha256 = "sha256-xakPkJxWj8KfolePOGxLC48C27GwhPPySxoVw+JPBPo=";
    #     })
    # ];
  };

  programs.obs-studio = { enable = true; };
}
