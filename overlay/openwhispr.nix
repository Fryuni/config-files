final: pkgs: {
  openwhispr = pkgs.appimageTools.wrapType2 {
    pname = "openwhispr";
    version = "1.5.5";

    src = pkgs.fetchurl {
      url = "https://github.com/OpenWhispr/openwhispr/releases/download/v1.5.5/OpenWhispr-1.5.5-linux-x86_64.AppImage";
      hash = "sha256-CSPtI1+8lYOvC6iQYe5vOpkaNbDvuEEQEXGCJTCVESE=";
    };

    extraPkgs = p:
      with p; [
        ydotool
        xdotool
        wl-clipboard
        wtype
        alsa-lib
        pulseaudio
      ];

    meta = {
      description = "Voice-to-text dictation app with local and cloud models";
      homepage = "https://github.com/OpenWhispr/openwhispr";
      license = pkgs.lib.licenses.mit;
      mainProgram = "openwhispr";
      platforms = ["x86_64-linux"];
    };
  };
}
