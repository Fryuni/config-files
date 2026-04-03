final: pkgs: {
  openwhispr = let
    pname = "openwhispr";
    version = "1.6.7";

    src = pkgs.fetchurl {
      url = "https://github.com/OpenWhispr/openwhispr/releases/download/v${version}/OpenWhispr-${version}-linux-x86_64.AppImage";
      hash = "sha256-AKBmdDbI5MNVDusN5TbCYUf21ZCTKNwiJHl6OqkTLUY=";
    };

    extracted = pkgs.appimageTools.extract {
      inherit pname version src;

      # Patch the launcher script: on Hyprland, don't force XWayland so that
      # the Hyprland D-Bus global hotkey path activates. The JS hotkey manager
      # checks process.argv for "--ozone-platform=x11" and skips D-Bus
      # registration if it's present.
      postExtract = ''
        substituteInPlace $out/open-whispr \
          --replace-fail \
            'FLAGS+=(--ozone-platform=x11)' \
            'if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then FLAGS+=(--ozone-platform=x11); fi'

        # Remove linux-fast-paste: its uinput method silently fails on native
        # Wayland (Ctrl+V not routed to the focused client) but reports success,
        # preventing the app from falling through to the tool-based paste chain.
        rm -f $out/resources/bin/linux-fast-paste $out/resources/resources/bin/linux-fast-paste

        # Patch clipboard.js inside the asar: reorder paste tool priority for
        # wlroots compositors (Hyprland/Sway). Put ydotool first because wtype
        # and xdotool both silently fail inside the bwrap sandbox — wtype's
        # virtual keyboard protocol doesn't cross the sandbox boundary, and
        # xdotool's XWayland events don't reach native Wayland clients.
        # ydotool communicates via a Unix socket to ydotoold on the host.
        # The replacement is the exact same byte length so asar offsets stay valid.
        ${pkgs.gnused}/bin/sed -i \
          's/candidates = \[...wtypeEntry, ...xdotoolEntry, ...ydotoolEntry\]/candidates = [...ydotoolEntry, ...xdotoolEntry, ...wtypeEntry]/' \
          $out/resources/app.asar


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
