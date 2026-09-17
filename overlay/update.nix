# Renders the shell script that dispatches registry-driven package updates.
#
# Evaluated by overlay/update.sh as:
#
#   UPDATE_FILTER="<name|empty>" \
#     nix eval --raw --impure --expr \
#       'import ./overlay/update.nix { filter = builtins.getEnv "UPDATE_FILTER"; }'
#
# The result is a bash script (with `set -euo pipefail`) that runs every
# updateable registry entry in deterministic (sorted) name order, or only the
# entry named by `filter`. Any updater failure aborts the run and propagates
# its exit status. This module only renders commands; it never adds staging,
# commits, or version changes of its own.
{filter ? ""}: let
  registry = import ./registry.nix;

  # POSIX single-quote escaping; args are passed as literal words.
  escapeShellArg = arg: "'" + builtins.replaceStrings ["'"] ["'\\''"] arg + "'";
  escapeShellArgs = args: builtins.concatStringsSep " " (map escapeShellArg args);

  # Registry packages are exported through packages.<system>, so nix-update
  # can resolve short names and use them directly in commit subjects.
  nixUpdate = name: args:
    "nix run nixpkgs#nix-update -- --commit --flake --system x86_64-linux "
    + escapeShellArg name
    + (
      if args == []
      then ""
      else " " + escapeShellArgs args
    );

  updateCommand = name: let
    update = registry.${name}.update or null;
  in
    if update == null
    then throw "registry entry ${name} has no automatic updater"
    else if update.kind == "nix-update"
    then nixUpdate name update.args
    else if update.kind == "command"
    then update.command
    else throw "registry entry ${name} has unknown update kind: ${update.kind}";

  names = builtins.attrNames registry;

  selected =
    if filter == ""
    then builtins.filter (name: registry.${name} ? update) names
    else if builtins.elem filter names
    then [filter]
    else throw "unknown registry entry: ${filter}";

  step = name: ''
    echo "==> Updating ${name}"
    ${updateCommand name}
  '';
in
  ''
    set -euo pipefail
  ''
  + builtins.concatStringsSep "\n" (map step selected)
