{config, ...}: {
  services.soft-serve = {
    enable = true;
    settings = {
      name = "Soft Serve";
      ssh = {
        listen_addr = "127.0.0.1:23231";
        public_url = "ssh://git-ss.rudd-agama.ts.net";
      };
      http = {
        listen_addr = "127.0.0.1:23232";
        public_url = "https://git-ss.rudd-agama.ts.net";
      };
      git = {
        listen_addr = "127.0.0.1:9418";
      };
      stats = {
        listen_addr = "127.0.0.1:23233";
      };
      allow-keyless = true;
      anon-access = "admin-access";
      initial_admin_keys = config.users.users.root.openssh.authorizedKeys.keys;
    };
  };

  services.tailscale.serve.services.git-ss.endpoints = {
    "tcp:22" = "tcp://localhost:23231";
    "tcp:443" = "tls-terminated-http://localhost:23232";
  };
}
