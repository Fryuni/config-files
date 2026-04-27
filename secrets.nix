let
  inherit (builtins) getEnv readDir map listToAttrs attrNames concatLists;
  keys = [
    # Master key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDWC3o9JGhJTmLg8q/NBVbaN1yXR9MVHln2xHO6WDlHp"
    # Dev key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN4weIfIxf3RMmhSII89HEGPqToqNKlwdYFW79CaBqCQ"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPZwBNlYpC3tigLKDxyU6+6jik0J63IIqT6DiFk7Dekc"
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
