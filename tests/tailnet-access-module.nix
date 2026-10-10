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
      {options.services.machineBackups = import ../common/backups/options.nix {inherit lib;};}
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
            dormant = {
              port = 8088;
              service = "example.service";
              idleTimeout = 300;
            };
            desktop = {
              port = 8089;
              service = "desktop.service";
              user = "lotus";
            };
            scripted = {
              port = 8090;
              startScript = "echo start";
              stopScript = "echo stop";
              idleTimeout = 60;
            };
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
      {options.services.machineBackups = import ../common/backups/options.nix {inherit lib;};}
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

  dnsEvaluated = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    inherit pkgs;
    modules = [
      tailnetAccessModule
      {options.services.machineBackups = import ../common/backups/options.nix {inherit lib;};}
      ageStubModule
      {
        system.stateVersion = "26.05";
        networking.hostName = "loem";

        services.lferrazTailnetAccess = {
          deviceName = "loem";
          publicDomain = "example.test";
          tailnetDomain = "tailnet.test";
          dns.enable = true;
          proxy.enable = false;
          certificates.enable = false;
        };
      }
    ];
  };

  cfg = evaluated.config;

  certificateService = cfg.systemd.services.lferraz-tailnet-certificate;
  certificateExecStart = certificateService.serviceConfig.ExecStart;
  onDemandService = cfg.systemd.services.lferraz-tailnet-on-demand;
  onDemandExecStart = onDemandService.serviceConfig.ExecStart;
  onDemandArguments = lib.splitString " " onDemandExecStart;
  invalidAliases = aliases: let
    invalid = evaluated.extendModules {
      modules = [{services.lferrazTailnetAccess.proxy.aliases = lib.mkForce aliases;}];
    };
  in
    map (assertion: assertion.message) (builtins.filter (assertion: !assertion.assertion) invalid.config.assertions);

  configJson = builtins.toJSON {
    dnsOnlyBackupDirectories = dnsEvaluated.config.services.machineBackups.directories;
    customBackupDirectories =
      (evaluated.extendModules {
        modules = [{services.caddy.dataDir = "/srv/tailnet-caddy";}];
      }).config.services.machineBackups.directories;
    extraConfig = cfg.services.caddy.virtualHosts.tailnet.extraConfig;
    emptyAliasesExtraConfig = emptyAliasesEvaluated.config.services.caddy.virtualHosts.tailnet.extraConfig;
    caddyHostName = cfg.services.caddy.virtualHosts.tailnet.hostName;
    caddyServerAliases = cfg.services.caddy.virtualHosts.tailnet.serverAliases;
    certificateAfter = certificateService.after;
    certificateRequires = certificateService.requires;
    certificateLoadCredential = certificateService.serviceConfig.LoadCredential;
    caKeyPath = cfg.age.secrets.lferraz-tailnet-ca-key.path;
    caKeySymlink = cfg.age.secrets.lferraz-tailnet-ca-key.symlink;
    coreDnsConfig = dnsEvaluated.config.services.coredns.config;
    resolvedConfig = dnsEvaluated.config.environment.etc."systemd/resolved.conf".text;
    onDemandUser = onDemandService.serviceConfig.User;
    onDemandGroup = onDemandService.serviceConfig.Group;
    onDemandRuntimeMode = onDemandService.serviceConfig.RuntimeDirectoryMode;
    onDemandPreserve = onDemandService.serviceConfig.RuntimeDirectoryPreserve;
    caddyAfter = cfg.systemd.services.caddy.after;
    emptyHasHelper = emptyAliasesEvaluated.config.systemd.services ? lferraz-tailnet-on-demand;
    disabledHasHelper =
      (evaluated.extendModules {
        modules = [{services.lferrazTailnetAccess.proxy.enable = false;}];
      }).config.systemd.services ? lferraz-tailnet-on-demand;
    invalidMissingStart = invalidAliases {bad.port = 8080;};
    invalidMissingStop = invalidAliases {
      bad = {
        port = 8080;
        startScript = "true";
        idleTimeout = 1;
      };
    };
    invalidMixedStart = invalidAliases {
      bad = {
        port = 8080;
        service = "example.service";
        startScript = "true";
      };
    };
    invalidScriptUser = invalidAliases {
      bad = {
        port = 8080;
        startScript = "true";
        user = "lotus";
      };
    };
    invalidDuplicatePort = invalidAliases {
      one = {
        port = 8080;
        service = "one.service";
      };
      two = {
        port = 8080;
        service = "two.service";
      };
    };
    invalidDuplicateUnit = invalidAliases {
      one = {
        port = 8080;
        service = "one.service";
      };
      two = {
        port = 8081;
        service = "one.service";
      };
    };
  };
in
  pkgs.runCommand "tailnet-access-module-check" {
    nativeBuildInputs = [pkgs.jq pkgs.openssl pkgs.caddy];
    inherit configJson certificateExecStart;
    onDemandExecutable = builtins.elemAt onDemandArguments 0;
    onDemandConfig = builtins.elemAt onDemandArguments 1;
    caddyConfig = cfg.services.caddy.configFile;
  } ''
    printf '%s\n' "$configJson" > config.json
    jq -e '.dnsOnlyBackupDirectories == []' config.json
    jq -e '.customBackupDirectories | any(.name == "caddy-state" and .paths == ["/srv/tailnet-caddy"] and .optional == true)' config.json
    jq -e '.caddyHostName == "https://note.tailnet.test"' config.json
    jq -e '.caddyServerAliases | index("https://*.note.example.test")' config.json
    jq -e '.caddyServerAliases | index("https://note.example.test")' config.json


    jq -e '.extraConfig | contains("@alias_node_red header_regexp alias_node_red Host ^node-red\\.note\\.example\\.test(?::[0-9]+)?$")' config.json
    jq -e '.extraConfig | contains("reverse_proxy 127.0.0.1:1880")' config.json
    jq -e '.extraConfig | contains("header_up Host 127.0.0.1:1880")' config.json

    # T3 Code's Effect HTTP client sends tracing headers on cross-origin discovery.
    jq -e '[.extraConfig | capture("Access-Control-Allow-Headers \"(?<headers>[^\"]+)\""; "g") | .headers | ascii_downcase | split(", ") | (index("b3") != null and index("traceparent") != null)] | length > 0 and all' config.json

    jq -e '.extraConfig | contains("@port_local header_regexp port_local Host ^([0-9]+)-local\\.note\\.example\\.test(?::[0-9]+)?$")' config.json
    jq -e '.extraConfig | contains("reverse_proxy localhost:{re.port_local.1}")' config.json
    jq -e '.extraConfig | contains("header_up Host localhost:{re.port_local.1}")' config.json
    jq -e '.extraConfig | contains("header_up Origin http://localhost:{re.port_local.1}")' config.json

    jq -e '.extraConfig | contains("@alias_static header_regexp alias_static Host ^static\\.note\\.example\\.test(?::[0-9]+)?$")' config.json
    jq -e '.extraConfig | contains("handle @alias_static")' config.json
    jq -e '.extraConfig | contains("root * /srv/static")' config.json
    jq -e '.extraConfig | contains("file_server")' config.json
    jq -e '.extraConfig | contains("header Content-Type \"text/html; charset=utf-8\"")' config.json
    jq -e '.extraConfig | contains("Use http://&lt;port&gt;.note.example.test or https://&lt;port&gt;.note.example.test to proxy a local HTTP service on this device.")' config.json
    jq -e '.extraConfig | contains("Use http://&lt;port&gt;-local.note.example.test or https://&lt;port&gt;-local.note.example.test when the service expects Host/Origin localhost:&lt;port&gt;.")' config.json
    jq -e '.extraConfig | contains("<li><a href=\"http://node-red.note.example.test\">http://node-red.note.example.test</a></li>")' config.json
    jq -e '.extraConfig | contains("<li><a href=\"https://node-red.note.example.test\">https://node-red.note.example.test</a></li>")' config.json
    jq -e '.extraConfig | contains("<li><a href=\"http://static.note.example.test\">http://static.note.example.test</a></li>")' config.json
    jq -e '.extraConfig | contains("<li><a href=\"https://static.note.example.test\">https://static.note.example.test</a></li>")' config.json
    jq -e '.extraConfig | test("</html>` 200\\n[[:space:]]*}")' config.json
    jq -e '.emptyAliasesExtraConfig | contains("<h2>Aliases</h2>") | not' config.json

    jq -e '.extraConfig | contains("reverse_proxy unix//run/lferraz-tailnet-on-demand/proxy.sock")' config.json
    jq -e '.extraConfig | contains("header_up Host dormant")' config.json
    jq -e '.onDemandUser == "root" and .onDemandGroup == "caddy" and .onDemandRuntimeMode == "0750" and .onDemandPreserve == "restart"' config.json
    jq -e '.caddyAfter | index("lferraz-tailnet-on-demand.service")' config.json
    jq -e '.emptyHasHelper == false and .disabledHasHelper == false' config.json
    jq -e '.invalidMissingStart | any(contains("exactly one"))' config.json
    jq -e '.invalidMissingStop | any(contains("needs stopScript"))' config.json
    jq -e '.invalidMixedStart | any(contains("exactly one"))' config.json
    jq -e '.invalidScriptUser | any(contains("user requires service"))' config.json
    jq -e '.invalidDuplicatePort | any(contains("distinct backend ports"))' config.json
    jq -e '.invalidDuplicateUnit | any(contains("same systemd service"))' config.json
    jq -e '.targets.dormant.start[1:] == ["start", "example.service"] and .targets.dormant.stop[1:] == ["stop", "example.service"]' "$onDemandConfig"
    jq -e '.targets.desktop.start[1:] == ["--user", "--machine=lotus@.host", "start", "desktop.service"]' "$onDemandConfig"
    jq -e '.targets.dormant.idleTimeout == 300 and .targets.desktop.idleTimeout == 0 and .checkInterval == 30' "$onDemandConfig"
    "$(jq -r '.targets.scripted.start[0]' "$onDemandConfig")" | grep -Fx start
    "$(jq -r '.targets.scripted.stop[0]' "$onDemandConfig")" | grep -Fx stop
    test -x "$onDemandExecutable"
    caddy adapt --config "$caddyConfig" --adapter caddyfile > caddy.json
    jq -e '[.. | objects | select(.handler? == "reverse_proxy") | .upstreams[]?.dial] | index("unix//run/lferraz-tailnet-on-demand/proxy.sock")' caddy.json

    jq -e '.certificateAfter | index("run-agenix.d.mount") | not' config.json
    jq -e '.certificateRequires | index("run-agenix.d.mount") | not' config.json
    jq -e '.certificateLoadCredential == ["lferraz-tailnet-ca-key:" + .caKeyPath]' config.json
    jq -e '.caKeyPath == "/run/lferraz-tailnet-ca-key"' config.json
    jq -e '.caKeySymlink == false' config.json

    jq -e '.coreDnsConfig | contains("rewrite stop")' config.json
    jq -e '.coreDnsConfig | contains("name regex ^(?:.*[.])?([^.]+)[.]example[.]test[.]$ {1}.tailnet.test.")' config.json
    jq -e '.coreDnsConfig | contains("answer auto")' config.json
    jq -e '.coreDnsConfig | contains("forward . 100.100.100.100 tls://45.90.28.0 tls://2a07:a8c0:: tls://45.90.30.0 tls://2a07:a8c1:: {")' config.json
    jq -e '.coreDnsConfig | contains("tls_servername f7fd51.dns.nextdns.io")' config.json
    jq -e '.coreDnsConfig | contains("policy sequential")' config.json
    jq -e '.coreDnsConfig | contains("failover SERVFAIL REFUSED")' config.json
    jq -e '.coreDnsConfig | contains("1.1.1.1") | not' config.json
    jq -e '.coreDnsConfig | contains("8.8.8.8") | not' config.json
    jq -e '.coreDnsConfig | contains(" IN CNAME ") | not' config.json

    jq -e '.resolvedConfig | contains("DNS=127.0.0.1\n")' config.json
    jq -e '.resolvedConfig | contains("Domains=~. ~example.test\n")' config.json

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
