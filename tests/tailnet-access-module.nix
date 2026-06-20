{
  lib,
  pkgs,
  tailnetAccessModule,
}: let
  ageStubModule = {lib, ...}: {
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
          symlink = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
        };
      }));
    };
  };

  evaluated = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    inherit pkgs;
    modules = [
      tailnetAccessModule
      ageStubModule
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

  emptyAliasesEvaluated = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    inherit pkgs;
    modules = [
      tailnetAccessModule
      ageStubModule
      {
        system.stateVersion = "26.05";
        networking.hostName = "note";

        services.lferrazTailnetAccess = {
          deviceName = "note";
          publicDomain = "example.test";
          tailnetDomain = "tailnet.test";
          dns.enable = false;
        };
      }
    ];
  };

  cfg = evaluated.config;

  certificateService = cfg.systemd.services.lferraz-tailnet-certificate;
  certificateExecStart = certificateService.serviceConfig.ExecStart;

  configJson = builtins.toJSON {
    extraConfig = cfg.services.caddy.virtualHosts.tailnet.extraConfig;
    emptyAliasesExtraConfig = emptyAliasesEvaluated.config.services.caddy.virtualHosts.tailnet.extraConfig;
    certificateAfter = certificateService.after;
    certificateRequires = certificateService.requires;
    certificateLoadCredential = certificateService.serviceConfig.LoadCredential;
    caKeyPath = cfg.age.secrets.lferraz-tailnet-ca-key.path;
    caKeySymlink = cfg.age.secrets.lferraz-tailnet-ca-key.symlink;
  };
in
  pkgs.runCommand "tailnet-access-module-check" {
    nativeBuildInputs = [pkgs.jq pkgs.openssl];
    inherit configJson certificateExecStart;
  } ''
    printf '%s\n' "$configJson" > config.json

    jq -e '.extraConfig | contains("@alias_node_red header_regexp alias_node_red Host ^node-red\\.note\\.example\\.test(?::[0-9]+)?$")' config.json
    jq -e '.extraConfig | contains("reverse_proxy 127.0.0.1:1880")' config.json
    jq -e '.extraConfig | contains("header_up Host 127.0.0.1:1880")' config.json

    jq -e '.extraConfig | contains("@port_local header_regexp port_local Host ^([0-9]+)-local\\.note\\.example\\.test(?::[0-9]+)?$")' config.json
    jq -e '.extraConfig | contains("reverse_proxy 127.0.0.1:{re.port_local.1}")' config.json
    jq -e '.extraConfig | contains("header_up Host localhost:{re.port_local.1}")' config.json
    jq -e '.extraConfig | contains("header_up Origin http://localhost:{re.port_local.1}")' config.json

    jq -e '.extraConfig | contains("@alias_static header_regexp alias_static Host ^static\\.note\\.example\\.test(?::[0-9]+)?$")' config.json
    jq -e '.extraConfig | contains("handle @alias_static")' config.json
    jq -e '.extraConfig | contains("root * /srv/static")' config.json
    jq -e '.extraConfig | contains("file_server")' config.json
    jq -e '.extraConfig | contains("header Content-Type \"text/html; charset=utf-8\"")' config.json
    jq -e '.extraConfig | contains("Use https://&lt;port&gt;.note.example.test to proxy a local HTTP service on this device.")' config.json
    jq -e '.extraConfig | contains("Use https://&lt;port&gt;-local.note.example.test when the service expects Host/Origin localhost:&lt;port&gt;.")' config.json
    jq -e '.extraConfig | contains("<li><a href=\"https://node-red.note.example.test\">https://node-red.note.example.test</a></li>")' config.json
    jq -e '.extraConfig | contains("<li><a href=\"https://static.note.example.test\">https://static.note.example.test</a></li>")' config.json
    jq -e '.extraConfig | test("</html>` 200\\n[[:space:]]*}")' config.json
    jq -e '.emptyAliasesExtraConfig | contains("<h2>Aliases</h2>") | not' config.json

    jq -e '.certificateAfter | index("run-agenix.d.mount") | not' config.json
    jq -e '.certificateRequires | index("run-agenix.d.mount") | not' config.json
    jq -e '.certificateLoadCredential == ["lferraz-tailnet-ca-key:" + .caKeyPath]' config.json
    jq -e '.caKeyPath == "/run/lferraz-tailnet-ca-key"' config.json
    jq -e '.caKeySymlink == false' config.json

    grep -F 'basicConstraints = critical,CA:FALSE' "$certificateExecStart"
    grep -F 'keyUsage = critical,digitalSignature,keyEncipherment' "$certificateExecStart"
    grep -F 'extendedKeyUsage = serverAuth' "$certificateExecStart"

    openssl x509 -in ${../common/certs/lferraz-tailnet-ca.crt} -noout -text > ca.txt
    grep -F 'X509v3 Basic Constraints: critical' ca.txt
    grep -F 'CA:TRUE, pathlen:0' ca.txt
    grep -F 'X509v3 Key Usage: critical' ca.txt
    grep -F 'Certificate Sign, CRL Sign' ca.txt

    touch "$out"
  ''
