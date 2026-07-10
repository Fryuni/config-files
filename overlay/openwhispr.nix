final: pkgs: {
  openwhispr = let
    pname = "openwhispr";
    version = "1.7.2";

    src = pkgs.fetchurl {
      url = "https://github.com/OpenWhispr/openwhispr/releases/download/v${version}/OpenWhispr-${version}-linux-x86_64.AppImage";
      hash = "sha256-EPJTZFtd2bQ026KNcI/FOHfoAMu96HKfJxTPceTc5jw=";
    };

    extracted = pkgs.appimageTools.extract {
      inherit pname version src;

      postExtract = ''

        rm -f $out/resources/bin/linux-fast-paste $out/resources/resources/bin/linux-fast-paste

        # Patch clipboard.js inside the asar without extracting or repacking it.
        # Equal-length replacement keeps asar offsets valid; one occurrence
        # prevents silently patching an unexpected upstream layout.
        ${pkgs.python3}/bin/python3 - "$out/resources/app.asar" <<'PY'
        from pathlib import Path
        import sys

        app_asar = Path(sys.argv[1])
        old = b"candidates = [...wtypeEntry, ...xdotoolEntry, ...ydotoolEntry]"
        new = b"candidates = [...ydotoolEntry, ...xdotoolEntry, ...wtypeEntry]"

        if len(old) != len(new):
            raise SystemExit("OpenWhispr asar patch must preserve byte length")

        contents = app_asar.read_bytes()
        initial_new_count = contents.count(new)
        if contents.count(old) != 1:
            raise SystemExit("expected exactly one unpatched OpenWhispr candidate list")

        updated = contents.replace(old, new, 1)
        if len(updated) != len(contents):
            raise SystemExit("OpenWhispr asar patch changed byte length")
        if updated.count(old) != 0:
            raise SystemExit("OpenWhispr asar patch left an unpatched candidate list")
        if updated.count(new) != initial_new_count + 1:
            raise SystemExit("OpenWhispr asar patch replaced an unexpected candidate list")

        app_asar.write_bytes(updated)
        PY

      '';
    };
  in
    pkgs.appimageTools.wrapAppImage {
      inherit pname version;
      src = extracted;

      extraPkgs = p:
        with p; [
          ydotool
          xdotool
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
