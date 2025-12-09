_: {
  age.identityPaths = [
    "/home/lotus/.ssh/id_ed25519"
  ];
  age.secrets = {
    github-key.file = ../secrets/github-key;
    nordvpn-credentials.file = ../secrets/nordvpn-credentials;
  };
}
