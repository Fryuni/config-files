{
  config,
  pkgs,
  ...
}: {
  services.victoriametrics = {
    enable = true;
    listenAddress = "127.0.0.1:8428";
    retentionPeriod = "1"; # 1 month
  };

  age.secrets.grafana-key = {
    rekeyFile = ../../../secrets/loem/grafana-key;
    owner = "grafana";
    group = "grafana";
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
      };
      security.secret_key = "$__file{${config.age.secrets.grafana-key.path}}";
    };
    provision = {
      enable = true;
      dashboards.settings.providers = [
        {
          name = "Provisioned Dashboards";
          options.path = ./dashboards;
        }
      ];
      datasources.settings.datasources = [
        {
          name = "VictoriaMetrics";
          type = "prometheus";
          url = "http://127.0.0.1:8428";
          isDefault = true;
          editable = false;
        }
      ];
    };
  };

  services.tailscale.serve = {
    enable = true;
    services = {
      grafana.endpoints."tcp:3000" = "http://localhost:3000";
      victoriametrics.endpoints."tcp:8428" = "http://localhost:8428";
    };
  };

  services.vmagent = {
    enable = true;
    prometheusConfig = {
      scrape_configs = [
        {
          job_name = "grafana";
          static_configs = [
            {
              targets = ["http://127.0.0.1:3000/metrics"];
            }
          ];
        }
      ];
    };
  };
}
