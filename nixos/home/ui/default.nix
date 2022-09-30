{ pkgs, ... }:
{
  imports = [
    ./xfce.nix
    ./xsession.nix
  ];

  home.packages = with pkgs; [
    calibre
    spotify
    flameshot
    discord-canary
    vlc
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

  xdg.mimeApps = import ./xdg-mime.nix {
    defaultBrowser = "xfce4-web-browser.desktop";
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
  };

}
