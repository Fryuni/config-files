_: {
  services.gitea = {
    enable = true;
    settings = {
      server = {
        DOMAIN = "gitea.rudd-agama.ts.net";
        ROOT_URL = "https://gitea.rudd-agama.ts.net/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3333;
        START_SSH_SERVER = true;
        SSH_PORT = 22;
        SSH_LISTEN_PORT = 2222;
      };
    };
  };

  services.tailscale.serve.services.gitea.endpoints = {
    "tcp:22" = "tcp://localhost:2222";
    "tcp:443" = "tls-terminated-http://localhost:3333";
  };
}
