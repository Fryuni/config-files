_: {
  age.identityPaths = [
    "/home/lotus/.ssh/id_ed25519"
  ];
  age.secrets = {
    cachix-agent-token = {
      file = ../../secrets/cachix-agent-token;
    };
  };
}
