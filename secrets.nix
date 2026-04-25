let
  inherit (builtins) getEnv trace readDir map listToAttrs attrNames;
  keys = [
    # Master key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDWC3o9JGhJTmLg8q/NBVbaN1yXR9MVHln2xHO6WDlHp"
    # Dev key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw"

    # Others
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOj2JU5S/JO6zJZhqwl0xbAOb7IlulESVXrvipnFXOXf"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILI4D6ddYz7WosKUA4Xr7R1cwLF/mpCSWrCSW3O9Ct7E"
  ];
  fileSecret = getEnv "FILE";
  secretsDir = readDir ./secrets;
  secretNames = attrNames secretsDir;
  secretPaths = map (name: "secrets/${name}") (secretNames ++ [fileSecret]);
  allSecrets = secretPaths;
in
  listToAttrs (map (name: {
      inherit name;
      value = {
        publicKeys = keys;
      };
    })
    allSecrets)
