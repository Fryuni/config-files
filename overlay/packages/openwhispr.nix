{
  fetchurl,
  python3,
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

    postExtract = ''

      rm -f $out/resources/bin/linux-fast-paste $out/resources/resources/bin/linux-fast-paste

      # Patch app.asar in place without extracting or repacking it.  Each
      # equal-length replacement retains archive offsets and fails closed if
      # the upstream source layout is not exactly the one we reviewed.
      ${python3}/bin/python3 - "$out/resources/app.asar" <<'PY'
      from pathlib import Path
      import sys

      app_asar = Path(sys.argv[1])
      patches = {
          # Since 1.9.2, wtype runs separately and other Wayland compositors
          # already prefer ydotool. Keep our preference for X11/wlroots too.
          "clipboard candidate list": (
              b"? [...xdotoolEntry, ...ydotoolEntry]",
              b"? [...ydotoolEntry, ...xdotoolEntry]",
          ),
          "plaintext token fallback": (
              b'cached = buf.toString("utf8");\n      return cached || null;',
              b'return buf.every(b=>b>31&&b<127)?buf.toString("utf8"):null;',
          ),
      }

      contents = app_asar.read_bytes()
      archive_size = len(contents)

      for name, (old, new) in patches.items():
          if len(old) != len(new):
              raise SystemExit(f"OpenWhispr {name} patch must preserve byte length")

          initial_new_count = contents.count(new)
          if contents.count(old) != 1:
              raise SystemExit(f"expected exactly one unpatched OpenWhispr {name}")

          contents = contents.replace(old, new, 1)
          if len(contents) != archive_size:
              raise SystemExit(f"OpenWhispr {name} patch changed archive size")
          if contents.count(old) != 0:
              raise SystemExit(f"OpenWhispr {name} patch left unpatched source")
          if contents.count(new) != initial_new_count + 1:
              raise SystemExit(f"OpenWhispr {name} patch introduced an unexpected source count")

          app_asar.write_bytes(contents)
      PY

    '';
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
