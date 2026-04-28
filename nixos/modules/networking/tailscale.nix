{
  config,
  pkgs,
  lib,
  ...
}: let
  # NOTE: Tailscale doesn't support configuring TLS-terminated HTTP services declaratively.
  #   See https://github.com/tailscale/tailscale/issues/18381
  # Use fork with hack fix arround this issue while waiting for official position from Tailscale.
  #   See https://github.com/tailscale/tailscale/issues/18381#issuecomment-4332462281
  package = pkgs.master.tailscale.overrideAttrs (_: {
    src = pkgs.fetchFromGitHub {
      owner = "Fryuni";
      repo = "tailscale";
      rev = "c0ccbd0458ea68736a93eac5ce5be35ab1204cd4";
      hash = "sha256-CUsp9t2eSNcGWNi1z30rc03jyL+2MonvZ92DEldyfFg=";
    };

    vendorHash = "sha256-5uzkG6NQh0znjgE6yV5b01y8bUlTvLqXyAoWbMRQNEY=";

    # Reason why it is meaningless also in the issue comment above.
    doCkeck = false;
  });
in {
  # make the tailscale command usable to users
  environment.systemPackages = [package];

  # enable the tailscale service
  services.tailscale = {
    inherit package;
    enable = true;
    useRoutingFeatures = "both";
  };

  networking.firewall = {
    # always allow traffic from your Tailscale network
    trustedInterfaces = [config.services.tailscale.interfaceName];

    # allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [config.services.tailscale.port];
  };

  services.vmagent = {
    prometheusConfig = {
      global = {
        scrape_interval = "15s";
        relabel_configs = [
          {
            target_label = "instance";
            replacement = config.networking.hostName;
          }
          {
            target_label = "host";
            replacement = config.networking.hostName;
          }
        ];
      };
      scrape_configs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = ["http://localhost:9100/metrics"];
            }
          ];
        }
        {
          job_name = "tailscale";
          static_configs = [
            {
              targets = ["http://100.100.100.100:80/metrics"];
            }
          ];
        }
      ];
    };
    remoteWrite.url = "http://victoriametrics.rudd-agama.ts.net/api/v1/write";
  };

  services.prometheus.exporters.node = {
    enable = lib.mkDefault config.services.vmagent.enable;
    port = 9100;
    listenAddress = "127.0.0.1";
  };
}
