_: {
  age.identityPaths = [
    "/home/lotus/.ssh/id_ed25519"
  ];
  age.secrets = {
    nordvpn-credentials.file = ../secrets/nordvpn-credentials;
  };
}
