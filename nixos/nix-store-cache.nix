{
  config,
  lib,
  ...
}: let
  # Hosts are cache peers only once their SSH host public key is checked in here.
  # The same host key is used by the Nix daemon as its client identity.
  hostKeyDir = ../secrets/host-keys;
  hostKeyFiles = builtins.attrNames (builtins.readDir hostKeyDir);
  publicKeyFiles = builtins.filter (name: builtins.match ".*\\.pub$" name != null) hostKeyFiles;
  stripPubExt = name: builtins.elemAt (builtins.match "^(.*)\\.pub$" name) 0;

  hostKeys = builtins.listToAttrs (map (name: {
      name = stripPubExt name;
      value = builtins.readFile (hostKeyDir + "/${name}");
    })
    publicKeyFiles);

  cacheHostNames = builtins.attrNames hostKeys;
  peerHostNames = builtins.filter (hostName: hostName != config.networking.hostName) cacheHostNames;
  cacheUri = hostName: "ssh://nix-ssh@${hostName}?ssh-key=/etc/ssh/ssh_host_ed25519_key&trusted=true&priority=50";
in {
  programs.ssh.knownHosts = lib.mapAttrs (_: publicKey: {inherit publicKey;}) hostKeys;

  nix = {
    sshServe = {
      enable = true;
      keys = builtins.attrValues hostKeys;
    };

    settings.substituters = map cacheUri peerHostNames;
  };
}
