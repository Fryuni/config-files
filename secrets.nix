let
  inherit (builtins) getEnv readDir map listToAttrs attrNames concatLists;
  keys = [
    # Master key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDWC3o9JGhJTmLg8q/NBVbaN1yXR9MVHln2xHO6WDlHp"
    # Dev key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw"

    # Others
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOj2JU5S/JO6zJZhqwl0xbAOb7IlulESVXrvipnFXOXf"
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILI4D6ddYz7WosKUA4Xr7R1cwLF/mpCSWrCSW3O9Ct7E"
  ];
  fileSecret = getEnv "FILE";

  readSecretsRecursive = dir: prefix: let
    entries = readDir dir;
    names = attrNames entries;
    processName = name: let
      type = entries.${name};
      entryPath = "${prefix}/${name}";
    in
      if type == "directory"
      then
        if entryPath == "secrets/host-keys" || entryPath == "secrets/rekeyed"
        then []
        else readSecretsRecursive (dir + "/${name}") entryPath
      else [entryPath];
  in
    concatLists (map processName names);

  secretPaths = readSecretsRecursive ./secrets "secrets";
  allSecrets =
    secretPaths
    ++ (
      if fileSecret != ""
      then [fileSecret]
      else []
    );
in
  listToAttrs (map (name: {
      inherit name;
      value = {
        publicKeys = keys;
      };
    })
    allSecrets)
