{
  lib,
  pkgs,
  ...
}: let
  stateDir = "/var/lib/cpa-manager-plus";
in {
  users.groups."cpa-manager-plus" = {};
  users.users."cpa-manager-plus" = {
    isSystemUser = true;
    group = "cpa-manager-plus";
  };

  systemd.services."cpa-manager-plus" = {
    description = "CPA Manager Plus service";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target" "cli-proxy-api.service"];
    after = ["network-online.target" "cli-proxy-api.service"];

    environment = {
      HTTP_ADDR = "127.0.0.1:18317";
      # The public hostname routes /v0/management/* back to this service, so
      # use CLIProxyAPI's loopback listener for CPAMP's own upstream requests.
      CPA_UPSTREAM_URL = "http://127.0.0.1:8317";
      USAGE_COLLECTOR_MODE = "http";
      USAGE_DATA_DIR = stateDir;
    };

    serviceConfig = {
      ExecStart = lib.getExe pkgs.cpa-manager-plus;
      Restart = "on-failure";
      StateDirectory = "cpa-manager-plus";
      StateDirectoryMode = "0750";
      User = "cpa-manager-plus";
      Group = "cpa-manager-plus";
      WorkingDirectory = stateDir;
    };
  };
}
