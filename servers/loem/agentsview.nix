{config, ...}: {
  home-manager.users.lotus.services.agentsview = {
    enable = true;
    publicOrigin = "https://aview.loem.lferraz.dev";
    customModelPricing = {
      k3 = {
        input = 3;
        output = 15;
        cacheRead = 0.3;
      };
    };
    postgres = {
      enable = true;
      url = "postgres://agentsview@localhost/agentsview?sslmode=disable";
      machine = "loem";
      push = {
        enable = true;
        interval = "30m";
      };
    };
  };

  services.lferrazTailnetAccess.proxy.aliases.aview = 3377;

  services.postgresql = {
    enable = true;
    ensureDatabases = ["agentsview"];
    ensureUsers = [
      {
        name = "agentsview";
        ensureDBOwnership = true;
      }
    ];
    extensions = ps: [ps.pgvector];
  };

  systemd.services.agentsview-postgresql-setup = {
    description = "Enable pgvector for AgentsView";
    after = ["postgresql-setup.service"];
    requires = ["postgresql-setup.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
    };
    script = ''
      ${config.services.postgresql.package}/bin/psql \
        -v ON_ERROR_STOP=1 \
        --dbname agentsview \
        --command 'CREATE EXTENSION IF NOT EXISTS vector'
    '';
  };
}
