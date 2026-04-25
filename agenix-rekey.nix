{
  config,
  lib,
  ...
}: let
  hostKeyPath = ./. + "/secrets/host-keys/${config.networking.hostName}.pub";
in {
  assertions = [
    {
      assertion = config.services.openssh.enable;
      message = "agenix-rekey uses /etc/ssh/ssh_host_ed25519_key, so OpenSSH must be enabled for ${config.networking.hostName}.";
    }
  ];

  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  age.rekey =
    {
      masterIdentities = ["/home/lotus/.ssh/id_ed25519"];
      storageMode = "local";
      localStorageDir = ./. + "/secrets/rekeyed/${config.networking.hostName}";
    }
    # Missing host-key files intentionally fall back to agenix-rekey's dummy
    # recipient so first builds for new machines can generate the real key.
    // lib.optionalAttrs (builtins.pathExists hostKeyPath) {
      hostPubkey = hostKeyPath;
    };
}
