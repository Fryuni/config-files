_: {
  age.identityPaths = [
    "/home/lotus/.ssh/id_ed25519"
  ];
  age.secrets = {
    nix-access-tokens.file = ../secrets/nix-access-tokens;
    nordvpn-credentials.file = ../secrets/nordvpn-credentials;
  };
}
