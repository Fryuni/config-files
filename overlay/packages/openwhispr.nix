{
  fetchurl,
  appimageTools,
  lib,
}: let
  pname = "openwhispr";
  version = "1.9.2";

  src = fetchurl {
    url = "https://github.com/OpenWhispr/openwhispr/releases/download/v${version}/OpenWhispr-${version}-linux-x86_64.AppImage";
    hash = "sha256-U6qI/R95qpATZHPMrlQijqE5efy5v83l9GSCx/Ri0W4=";
  };

  extracted = appimageTools.extract {
    inherit pname version src;
  };
in
  appimageTools.wrapAppImage {
    inherit pname version;
    src = extracted;

    extraPkgs = p:
      with p; [
        ydotool
        xdotool
        alsa-lib
        pulseaudio
      ];

    passthru.appImage = src;

    meta = {
      description = "Voice-to-text dictation app with local and cloud models";
      homepage = "https://github.com/OpenWhispr/openwhispr";
      license = lib.licenses.mit;
      mainProgram = "openwhispr";
      platforms = ["x86_64-linux"];
    };
  }
