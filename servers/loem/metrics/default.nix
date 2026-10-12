{
  config,
  lib,
  pkgs,
  ...
}: let
  grafanaHost = "grafana.${config.services.lferrazTailnetAccess.baseHost}";
in {
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

  age.secrets.grafana-automation-credentials = {
    rekeyFile = ../../../secrets/loem/grafana-automation-credentials;
    mode = "0400";
  };

  # Preserve the browser's Host and Origin for Grafana's CSRF and Live checks.
  services.lferrazTailnetAccess.proxy.aliases.grafana = ''
    reverse_proxy 127.0.0.1:${toString config.services.grafana.settings.server.http_port}
  '';

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        domain = grafanaHost;
        root_url = "https://${grafanaHost}/";
      };
      security = {
        secret_key = "$__file{${config.age.secrets.grafana-key.path}}";
        cookie_secure = true;
      };
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
          # Pinned so provisioned dashboards can reference the datasource by uid
          # instead of relying on Grafana's generated one.
          uid = "victoriametrics";
          url = "http://127.0.0.1:8428";
          isDefault = true;
          editable = false;
        }
      ];
    };
  };

  services.machineBackups = lib.mkMerge [
    (lib.mkIf config.services.victoriametrics.enable {
      captures.victoriametrics = {
        kind = "victoria";
        paths = [];
        url = "http://${config.services.victoriametrics.listenAddress}";
        storagePath = "/var/lib/${config.services.victoriametrics.stateDir}";
      };
      extraPackages = [config.services.victoriametrics.package];
    })
    (lib.mkIf config.services.grafana.enable {
      directories = [
        {
          name = "grafana";
          kind = "sqlite";
          paths = [config.services.grafana.dataDir config.age.secrets.grafana-key.path];
          units = [{name = "grafana.service";}];
        }
      ];
    })
  ];

  services.tailscale.serve = {
    enable = true;
    services = {
      victoriametrics.endpoints = {
        "tcp:80" = "http://localhost:8428";
      };
    };
  };

  services.vmagent = {
    enable = true;
    extraArgs = ["-httpListenAddr=127.0.0.1:8429"];
    prometheusConfig = {
      scrape_configs =
        [
          {
            job_name = "grafana";
            static_configs = [
              {
                targets = ["http://127.0.0.1:3000/metrics"];
              }
            ];
          }
        ]
        ++ lib.mapAttrsToList (job: port: {
          job_name = job;
          static_configs = [{targets = ["127.0.0.1:${toString port}"];}];
        }) {
          victoriametrics = 8428;
          vmagent = 8429;
          soft-serve = 23233;
          cloudflared = 20241;
          caddy = 2019;
        };
    };
  };
}
