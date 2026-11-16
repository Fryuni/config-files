{
  config,
  lib,
  pkgs,
  ...
}: let
  alias = "novelmaker";
  host = "${alias}.${config.networking.hostName}.${config.services.lferrazTailnetAccess.publicDomain}";
  stateDir = "/var/lib/novelmaker";
  # The proxy's generic <port>.<host> routes forward any localhost port with
  # permissive cross-origin headers, which would bypass the alias's origin
  # check. They cannot target another loopback address, so listen on one.
  address = "127.0.0.32";
  # Upstream's default, 3000, belongs to Grafana.
  port = 3210;
in {
  users.groups.novelmaker = {};
  users.users.novelmaker = {
    isSystemUser = true;
    group = "novelmaker";
  };

  systemd.services.novelmaker = {
    description = "Novelmaker writing app";
    wantedBy = ["multi-user.target"];

    environment = {
      HOST = address;
      PORT = toString port;
      NOVELMAKER_DATA = stateDir;
    };

    serviceConfig = {
      ExecStart = lib.getExe pkgs.novelmaker;
      # "Quit Novelmaker" in the interface exits cleanly; bring it back.
      Restart = "always";
      StateDirectory = "novelmaker";
      StateDirectoryMode = "0700";
      User = "novelmaker";
      Group = "novelmaker";

      # The interface has no sign-in and can point the database and backup
      # folders at any path, so confine what the service can reach.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
    };
  };

  services.machineBackups.directories = [
    {
      name = "novelmaker";
      kind = "sqlite";
      paths = [stateDir];
      # Stopping the server would drop the editor's autosaves, so it stays online.
      writerCoverageNote = "The manuscript database and Novelmaker's own backup copies use consistent online exports. config.json is read live.";
    }
  ];

  # The app has no sign-in, so the proxy must stop other websites from using a
  # Tailnet browser to reach it: no cross-origin headers (port aliases add
  # them), and no requests sent from a foreign origin.
  services.lferrazTailnetAccess.proxy.aliases.${alias} = ''
    @foreign {
      header Origin *
      not header_regexp Origin ^https?://${lib.escapeRegex host}$
    }
    respond @foreign 403

    reverse_proxy ${address}:${toString port}
  '';
}
