{
  rustCrates,
  gum,
  writeShellScriptBin,
}: let
  inherit (rustCrates) zellij;
in
  writeShellScriptBin "__start_zellij" ''
    trim() {
      local var="$*"
      # remove leading whitespace characters
      var="''${var#"''${var%%[![:space:]]*}"}"
      # remove trailing whitespace characters
      var="''${var%"''${var##*[![:space:]]}"}"
      printf '%s' "$var"
    }

    start_zellij() {
      local session_name="$1"

      if [ -z "$session_name"]; then
        ${gum}/bin/gum style --faint --italic --bold "Zellij session name:"

        session_name=$(${gum}/bin/gum input --char-limit=40)
      fi

      if [ -z "$session_name" ]; then
        exec ${zellij}/bin/zellij
      else
        exec ${zellij}/bin/zellij -s "$session_name"
      fi
    }

    if [ -z "$ZELLIJ" ]; then
      ongoing_sessions=$(trim "$(${zellij}/bin/zellij ls 2>/dev/null)")

      if [ -z "$ongoing_sessions" ]; then
        start_zellij main
      else
        ${gum}/bin/gum style --faint --italic --bold "Chose a session (or create a new one):"

        pick_options=$(trim "''${ongoing_sessions}\nCreate new session")
        chosen=$(echo -e "$pick_options" | ${gum}/bin/gum filter)

        if [ "$chosen" = "Create new session" ]; then
          ${gum}/bin/gum style --faint --italic -- "--> $chosen"
          start_zellij
        else
          exec ${zellij}/bin/zellij attach "$chosen"
        fi
      fi
    fi
  ''
