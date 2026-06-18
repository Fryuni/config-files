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

  services.lferrazTailnetAccess.proxy.aliases.llm = port;
}
