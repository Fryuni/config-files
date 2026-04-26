_: let
  files = builtins.attrNames (builtins.readDir ../secrets/host-keys);
  txtFiles = builtins.filter (name: builtins.match ".*\\.pub$" name != null) files;
  stripExt = name: builtins.elemAt (builtins.match "^(.*)\\.pub$" name) 0;
  hosts = builtins.listToAttrs (map
    (name: {
      name = stripExt name;
      value = {
        publicKey = builtins.readFile (../secrets/host-keys + "/${name}");
      };
    })
    txtFiles);
in {
  programs.ssh.knownHosts = hosts;
}
