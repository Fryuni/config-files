{
  lib,
  pkgs,
  tailnetAccessModule,
}: let
  evaluated = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    inherit pkgs;
    modules = [
      tailnetAccessModule
      ({lib, ...}: {
        options.age.secrets = lib.mkOption {
          default = {};
          type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
            options = {
              rekeyFile = lib.mkOption {
                type = lib.types.path;
              };
              path = lib.mkOption {
                type = lib.types.str;
                default = "/run/agenix/${name}";
              };
              owner = lib.mkOption {
                type = lib.types.str;
              };
              group = lib.mkOption {
                type = lib.types.str;
              };
              mode = lib.mkOption {
                type = lib.types.str;
              };
            };
          }));
        };
      })
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

  certificateService = cfg.systemd.services.lferraz-tailnet-certificate;

  configJson = builtins.toJSON {
    extraConfig = cfg.services.caddy.virtualHosts.tailnet.extraConfig;
    certificateAfter = certificateService.after;
    certificateRequires = certificateService.requires;
    certificateLoadCredential = certificateService.serviceConfig.LoadCredential;
    caKeyPath = cfg.age.secrets.lferraz-tailnet-ca-key.path;
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

    jq -e '.certificateAfter | index("run-agenix.d.mount") | not' config.json
    jq -e '.certificateRequires | index("run-agenix.d.mount") | not' config.json
    jq -e '.certificateLoadCredential == ["lferraz-tailnet-ca-key:" + .caKeyPath]' config.json

    touch "$out"
  ''
