{
  fetchurl,
  appimageTools,
  lib,
}: let
  pname = "openwhispr";
  version = "1.10.0";

  src = fetchurl {
    url = "https://github.com/OpenWhispr/openwhispr/releases/download/v${version}/OpenWhispr-${version}-linux-x86_64.AppImage";
    hash = "sha256-OrspqlFsyu2GRhi5elci7SyaFgw1fvMnHZKYd+hdgVI=";
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
