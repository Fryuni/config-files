{
  lib,
  pkgs,
  ...
}: let
  stateDir = "/var/lib/cli-proxy-api";
  port = 8317;
  seedConfigFile = (pkgs.formats.yaml {}).generate "cli-proxy-api.yaml" {
    host = "127.0.0.1";
    inherit port;
    "auth-dir" = "${stateDir}/auth";
    "remote-management" = {
      "allow-remote" = true;
    };
  };
  configFile = "${stateDir}/config.yaml";
  managementPasswordFile = "${stateDir}/management-password";
  cpaManagerPlusHandler = ''
    @cpa_manager_plus path / /management.html /setup /status /health /usage-service/* /v0/management/* /v0/resource/plugins/* /v1/models /v1/models/ /models /models/
    handle @cpa_manager_plus {
      header {
        >Access-Control-Allow-Origin "{http.request.header.Origin}"
        >Access-Control-Allow-Credentials "true"
        >Access-Control-Allow-Methods "GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS"
        >Access-Control-Allow-Headers "Authorization, Content-Type, Accept, Origin, User-Agent, DNT, Cache-Control, X-Requested-With, If-Modified-Since, Range"
        >Access-Control-Expose-Headers "Content-Length, Content-Range"
        >Access-Control-Max-Age "3600"
        >Vary "Origin"
      }

      @cpa_manager_plus_preflight method OPTIONS
      respond @cpa_manager_plus_preflight "" 204

      reverse_proxy 127.0.0.1:18317 {
        header_up Host 127.0.0.1:18317
      }
    }

    handle {
      header {
        >Access-Control-Allow-Origin "{http.request.header.Origin}"
        >Access-Control-Allow-Credentials "true"
        >Access-Control-Allow-Methods "GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS"
        >Access-Control-Allow-Headers "Authorization, Content-Type, Accept, Origin, User-Agent, DNT, Cache-Control, X-Requested-With, If-Modified-Since, Range"
        >Access-Control-Expose-Headers "Content-Length, Content-Range"
        >Access-Control-Max-Age "3600"
        >Vary "Origin"
      }

      @cli_proxy_api_preflight method OPTIONS
      respond @cli_proxy_api_preflight "" 204

      reverse_proxy 127.0.0.1:${toString port} {
        header_up Host 127.0.0.1:${toString port}
      }
    }
  '';
  cliProxyApi = pkgs.writeShellScriptBin "cli-proxy-api" ''
    export MANAGEMENT_PASSWORD="$(<${managementPasswordFile})"
    exec ${lib.getExe pkgs.llm-agents.cli-proxy-api} "$@"
  '';
in {
  users.groups."cli-proxy-api" = {};
  users.users."cli-proxy-api" = {
    isSystemUser = true;
    group = "cli-proxy-api";
  };

  systemd.services."cli-proxy-api" = {
    description = "CLIProxyAPI service";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];

    environment.WRITABLE_PATH = stateDir;

    preStart = ''
      ${pkgs.coreutils}/bin/install -d -m 0750 ${stateDir}/auth ${stateDir}/static
      if [[ ! -e ${configFile} ]]; then
        ${pkgs.coreutils}/bin/install -m 0640 ${seedConfigFile} ${configFile}
      fi
      if [[ ! -e ${managementPasswordFile} ]]; then
        umask 0077
        ${pkgs.openssl}/bin/openssl rand -base64 32 > ${managementPasswordFile}
      fi
    '';

    serviceConfig = {
      ExecStart = "${lib.getExe cliProxyApi} -config ${configFile}";
      Restart = "on-failure";
      StateDirectory = "cli-proxy-api";
      StateDirectoryMode = "0750";
      User = "cli-proxy-api";
      Group = "cli-proxy-api";
      WorkingDirectory = stateDir;
    };
  };

  services.lferrazTailnetAccess.proxy.aliases.llm = cpaManagerPlusHandler;
}
