{
  pkgs,
  lib,
  ...
}: let
  # UUID for the Vicinae toggle shortcut (stable, deterministic)
  vicinaeUuid = "{a1b2c3d4-e5f6-7890-abcd-vicinae00001}";

  # Use kwriteconfig6 to set KDE config entries without overwriting entire files.
  # KDE modifies these files at runtime, so declarative file management would
  # conflict with the running desktop.
  kwrite = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";
  kread = "${pkgs.kdePackages.kconfig}/bin/kreadconfig6";
in {
  # Register the custom shortcut action in khotkeysrc
  # and bind it in kglobalshortcutsrc on every activation
  home.activation.plasmaShortcuts = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # --- khotkeysrc: Define the Vicinae toggle action ---

    # Ensure a "Vicinae" group exists at the next available Data slot.
    # First, check if we already created it (idempotent).
    KHOTKEYS="$HOME/.config/khotkeysrc"
    if ! ${pkgs.gnugrep}/bin/grep -q 'Name=Vicinae Launcher' "$KHOTKEYS" 2>/dev/null; then
      # Find current DataCount and increment it
      CURRENT_COUNT=$(${kread} --file "$KHOTKEYS" --group "Data" --key "DataCount" 2>/dev/null || echo "0")
      if [ -z "$CURRENT_COUNT" ] || [ "$CURRENT_COUNT" = "0" ]; then
        CURRENT_COUNT=0
      fi
      NEW_COUNT=$((CURRENT_COUNT + 1))

      ${kwrite} --file "$KHOTKEYS" --group "Data" --key "DataCount" "$NEW_COUNT"

      # Create the group
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}" --key "Comment" "Vicinae launcher toggle"
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}" --key "Enabled" "true"
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}" --key "Name" "Vicinae Launcher"
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}" --key "Type" "SIMPLE_ACTION_DATA"

      # Action: run command
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}Actions" --key "ActionsCount" "1"
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}Actions0" --key "CommandURL" "vicinae toggle"
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}Actions0" --key "Type" "COMMAND_URL"

      # Conditions (none)
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}Conditions" --key "Comment" ""
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}Conditions" --key "ConditionsCount" "0"

      # Trigger: keyboard shortcut
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}Triggers" --key "Comment" "Simple_action"
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}Triggers" --key "TriggersCount" "1"
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}Triggers0" --key "Key" "Meta+Space"
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}Triggers0" --key "Type" "SHORTCUT"
      ${kwrite} --file "$KHOTKEYS" --group "Data_''${NEW_COUNT}Triggers0" --key "Uuid" "${vicinaeUuid}"
    fi

    # --- kglobalshortcutsrc: Register the keybinding ---
    ${kwrite} --file "$HOME/.config/kglobalshortcutsrc" \
      --group "khotkeys" \
      --key "${vicinaeUuid}" \
      "Meta+Space,none,Toggle Vicinae"
  '';
}
