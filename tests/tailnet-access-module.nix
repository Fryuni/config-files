{
  agenixModule,
  lib,
  pkgs,
  tailnetAccessModule,
}: let
  evaluated = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    inherit pkgs;
    modules = [
      agenixModule
      tailnetAccessModule
      {
        system.stateVersion = "26.05";
        networking.hostName = "note";

        services.lferrazTailnetAccess = {
          deviceName = "note";
          publicDomain = "example.test";
          tailnetDomain = "tailnet.test";
          dns.enable = false;
          proxy.aliases = {
            node-red = 1880;
            static = ''
              root * /srv/static
              file_server
            '';
          };
        };
      }
    ];
  };

  cfg = evaluated.config;

  configJson = builtins.toJSON {
    extraConfig = cfg.services.caddy.virtualHosts.tailnet.extraConfig;
  };
in
  pkgs.runCommand "tailnet-access-module-check" {
    nativeBuildInputs = [pkgs.jq];
    inherit configJson;
  } ''
    printf '%s\n' "$configJson" > config.json

    jq -e '.extraConfig | contains("@alias_node_red header_regexp alias_node_red Host ^node-red\\.note\\.example\\.test(?::[0-9]+)?$")' config.json
    jq -e '.extraConfig | contains("reverse_proxy 127.0.0.1:1880")' config.json
    jq -e '.extraConfig | contains("header_up Host 127.0.0.1:1880")' config.json

    jq -e '.extraConfig | contains("@alias_static header_regexp alias_static Host ^static\\.note\\.example\\.test(?::[0-9]+)?$")' config.json
    jq -e '.extraConfig | contains("handle @alias_static")' config.json
    jq -e '.extraConfig | contains("root * /srv/static")' config.json
    jq -e '.extraConfig | contains("file_server")' config.json

    touch "$out"
  ''
