{
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
}
