let
  inherit (builtins) getEnv trace readDir map listToAttrs attrNames;
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILI4D6ddYz7WosKUA4Xr7R1cwLF/mpCSWrCSW3O9Ct7E luiz@lferraz.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw luiz@lferraz.com"
  ];
  fileSecret = getEnv "FILE";
  secretsDir = readDir ./secrets;
  secretNames = attrNames secretsDir;
  secretPaths = map (name: "secrets/${name}") secretNames;
  allSecrets = secretPaths ++ [fileSecret];
in
  listToAttrs (map (name: {
      inherit name;
      value = {
        publicKeys = keys;
      };
    })
    allSecrets)
