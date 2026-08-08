{
  lib,
  pkgs,
  ...
}: let
  stateDir = "/var/lib/cpa-manager-plus";
  cpaManagerPlus = pkgs.stdenvNoCC.mkDerivation {
    pname = "cpa-manager-plus";
    version = "1.11.12";

    src = pkgs.fetchurl {
      url = "https://github.com/seakee/CPA-Manager-Plus/releases/download/v1.11.12/cpa-manager-plus_v1.11.12_linux_amd64.tar.gz";
      hash = "sha256-z2KHzZoDO68XwIb+5emVyiuse68Cl1qyYG1meIbfkTI=";
    };

    sourceRoot = "cpa-manager-plus_v1.11.12_linux_amd64";
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      install -Dm755 cpa-manager-plus $out/bin/cpa-manager-plus
      install -Dm755 cpa-manager-plusctl $out/bin/cpa-manager-plusctl
    '';

    meta.mainProgram = "cpa-manager-plus";
  };
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
      ExecStart = lib.getExe cpaManagerPlus;
      Restart = "on-failure";
      StateDirectory = "cpa-manager-plus";
      StateDirectoryMode = "0750";
      User = "cpa-manager-plus";
      Group = "cpa-manager-plus";
      WorkingDirectory = stateDir;
    };
  };
}
