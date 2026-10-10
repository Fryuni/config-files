{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.lferrazTailnetAccess;

  inherit (lib) mkEnableOption mkIf mkMerge mkOption mkForce types;
  inherit (cfg) deviceName publicDomain tailnetDomain;

  regexPublicDomain = lib.replaceStrings ["."] ["[.]"] publicDomain;
  tailnetHost = "${deviceName}.${tailnetDomain}";

  # NextDNS over TLS, used for anything Tailscale's resolver cannot answer.
  nextDnsServerName = "f7fd51.dns.nextdns.io";
  nextDnsServers = ["45.90.28.0" "2a07:a8c0::" "45.90.30.0" "2a07:a8c1::"];

  caCert = ../../../common/certs/lferraz-tailnet-ca.crt;
  certStateDir = "/var/lib/lferraz-tailnet";
  certDir = "${certStateDir}/certs";
  certFile = "${certDir}/${deviceName}.crt";
  certKeyFile = "${certDir}/${deviceName}.key";
  caKeyCredential = "/run/lferraz-tailnet-ca-key";

  systemTrustEnvironment = {
    BUN_OPTIONS = lib.mkDefault "--use-system-ca";
  };

  onDemandAliases = lib.filterAttrs (_: builtins.isAttrs) cfg.proxy.aliases;
  onDemandRuntimeDir = "/run/lferraz-tailnet-on-demand";
  onDemandSocket = "${onDemandRuntimeDir}/proxy.sock";
  onDemandPackage = pkgs.buildGoModule {
    pname = "tailnet-on-demand";
    version = "1";
    src = ./tailnet-on-demand;
    vendorHash = null;
    doCheck = true;
    meta.mainProgram = "tailnet-on-demand";
  };
  serviceCommand = target: action:
    ["${pkgs.systemd}/bin/systemctl"]
    ++ lib.optionals (target.user != null) ["--user" "--machine=${target.user}@.host"]
    ++ [action target.service];
  scriptCommand = alias: action: script:
    lib.optional (script != null) (toString (pkgs.writeShellScript "tailnet-${alias}-${action}" ''
      set -euo pipefail
      ${script}
    ''));
  onDemandConfig = pkgs.writeText "tailnet-on-demand.json" (builtins.toJSON {
    socket = onDemandSocket;
    stateDir = "${onDemandRuntimeDir}/state";
    checkInterval = cfg.proxy.idleCheckInterval;
    targets =
      lib.mapAttrs (alias: target: {
        inherit (target) port startupTimeout stopTimeout;
        idleTimeout =
          if target.idleTimeout == null
          then 0
          else target.idleTimeout;
        start =
          if target.service != null
          then serviceCommand target "start"
          else scriptCommand alias "start" target.startScript;
        stop =
          if target.service != null
          then serviceCommand target "stop"
          else scriptCommand alias "stop" target.stopScript;
      })
      onDemandAliases;
  });

  portProxyHandlerWithHeaders = {
    upstream,
    hostHeader ? upstream,
    originHeader ? null,
    preflight ? true,
  }: ''
    header {
      >Access-Control-Allow-Origin "{http.request.header.Origin}"
      >Access-Control-Allow-Credentials "true"
      >Access-Control-Allow-Methods "GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS"
      >Access-Control-Allow-Headers "Authorization, Content-Type, Accept, Origin, User-Agent, DNT, Cache-Control, X-Requested-With, If-Modified-Since, Range, b3, traceparent"
      >Access-Control-Expose-Headers "Content-Length, Content-Range"
      >Access-Control-Max-Age "3600"
      >Vary "Origin"
    }

    ${lib.optionalString preflight ''
      @preflight method OPTIONS
      respond @preflight "" 204
    ''}

    reverse_proxy ${upstream} {
      header_up Host ${hostHeader}
      ${lib.optionalString (originHeader != null) "header_up Origin ${originHeader}"}
    }
  '';
  portProxyHandler = upstream: portProxyHandlerWithHeaders {inherit upstream;};
  localPortProxyHandler = port:
    portProxyHandlerWithHeaders {
      upstream = "localhost:${port}";
      hostHeader = "localhost:${port}";
      originHeader = "http://localhost:${port}";
    };

  matcherName = alias: lib.replaceStrings ["-" "."] ["_" "_"] alias;
  aliasHostRegexp = alias: "^${lib.escapeRegex alias}\\.${lib.escapeRegex deviceName}\\.${lib.escapeRegex publicDomain}(?::[0-9]+)?$";
  portHostRegexp = "^([0-9]+)\\.${lib.escapeRegex deviceName}\\.${lib.escapeRegex publicDomain}(?::[0-9]+)?$";
  portLocalHostRegexp = "^([0-9]+)-local\\.${lib.escapeRegex deviceName}\\.${lib.escapeRegex publicDomain}(?::[0-9]+)?$";
  aliasProxyBlocks = lib.concatStringsSep "\n" (lib.mapAttrsToList (alias: target: let
      matcher = "alias_${matcherName alias}";
      handler =
        if builtins.isInt target
        then portProxyHandler "127.0.0.1:${toString target}"
        else if builtins.isAttrs target
        then
          portProxyHandlerWithHeaders {
            upstream = "unix/${onDemandSocket}";
            hostHeader = alias;
            preflight = false;
          }
        else target;
    in ''
      @${matcher} header_regexp ${matcher} Host ${aliasHostRegexp alias}
      handle @${matcher} {
        ${handler}
      }
    '')
    cfg.proxy.aliases);
  aliasNames = builtins.attrNames cfg.proxy.aliases;
  aliasUrls = alias: [
    "http://${alias}.${deviceName}.${publicDomain}"
    "https://${alias}.${deviceName}.${publicDomain}"
  ];
  aliasListItems =
    lib.concatMapStringsSep "\n" (
      alias:
        lib.concatMapStringsSep "\n" (
          url: ''<li><a href="${url}">${url}</a></li>''
        ) (aliasUrls alias)
    )
    aliasNames;
  aliasListHtml = lib.optionalString (aliasNames != []) ''
    <section>
      <h2>Aliases</h2>
      <ul>
        ${aliasListItems}
      </ul>
    </section>
  '';
  validAliasName = alias: builtins.match "[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?" alias != null && builtins.match "[0-9]+" alias == null;

  issueCertificate = pkgs.writeShellApplication {
    name = "lferraz-tailnet-issue-cert";
    runtimeInputs = with pkgs; [
      coreutils
      openssl
    ];
    text = ''
      set -euo pipefail

      usage() {
        cat <<'USAGE'
      Usage: lferraz-tailnet-issue-cert <common-name> <output-directory> [SAN ...]

      Examples:
        sudo lferraz-tailnet-issue-cert note.lferraz.dev /tmp/certs \
          note.rudd-agama.ts.net '*.note.lferraz.dev'

      The CA private key is stored as an agenix secret, so this normally needs sudo.
      USAGE
      }

      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 64
      fi

      common_name=$1
      output_dir=$2
      shift 2

      install -d -m 0750 "$output_dir"
      work_dir=$(mktemp -d)
      trap 'rm -rf "$work_dir"' EXIT

      san_entries="DNS:$common_name"
      for san in "$@"; do
        san_entries="$san_entries,DNS:$san"
      done

      cat >"$work_dir/openssl.cnf" <<EOF
      [req]
      distinguished_name = req_distinguished_name
      req_extensions = req_ext
      prompt = no

      [req_distinguished_name]
      CN = $common_name

      [req_ext]
      subjectAltName = $san_entries
      basicConstraints = critical,CA:FALSE
      keyUsage = critical,digitalSignature,keyEncipherment
      extendedKeyUsage = serverAuth
      EOF

      openssl genrsa -out "$work_dir/cert.key" 2048 >/dev/null 2>&1
      openssl req -new \
        -key "$work_dir/cert.key" \
        -out "$work_dir/cert.csr" \
        -config "$work_dir/openssl.cnf"
      openssl x509 -req \
        -in "$work_dir/cert.csr" \
        -CA ${caCert} \
        -CAkey ${config.age.secrets.lferraz-tailnet-ca-key.path} \
        -CAcreateserial \
        -CAserial "${certStateDir}/ca.srl" \
        -out "$work_dir/cert.crt" \
        -days ${toString cfg.certificates.leafDays} \
        -sha256 \
        -extensions req_ext \
        -extfile "$work_dir/openssl.cnf"

      install -m 0644 "$work_dir/cert.crt" "$output_dir/$common_name.crt"
      install -m 0600 "$work_dir/cert.key" "$output_dir/$common_name.key"
      echo "$output_dir/$common_name.crt"
      echo "$output_dir/$common_name.key"
    '';
  };

  generateHostCertificate = pkgs.writeShellApplication {
    name = "lferraz-tailnet-generate-host-cert";
    runtimeInputs = with pkgs; [
      coreutils
      openssl
    ];
    text = ''
      set -euo pipefail

      install -d -m 0750 -o root -g caddy ${certDir}
      work_dir=$(mktemp -d)
      trap 'rm -rf "$work_dir"' EXIT

      cat >"$work_dir/openssl.cnf" <<EOF
      [req]
      distinguished_name = req_distinguished_name
      req_extensions = req_ext
      prompt = no

      [req_distinguished_name]
      CN = ${deviceName}.${publicDomain}

      [req_ext]
      subjectAltName = DNS:${tailnetHost},DNS:${deviceName}.${publicDomain},DNS:*.${deviceName}.${publicDomain}
      basicConstraints = critical,CA:FALSE
      keyUsage = critical,digitalSignature,keyEncipherment
      extendedKeyUsage = serverAuth
      EOF

      openssl genrsa -out "$work_dir/${deviceName}.key" 2048 >/dev/null 2>&1
      openssl req -new \
        -key "$work_dir/${deviceName}.key" \
        -out "$work_dir/${deviceName}.csr" \
        -config "$work_dir/openssl.cnf"
      openssl x509 -req \
        -in "$work_dir/${deviceName}.csr" \
        -CA ${caCert} \
        -CAkey "$CREDENTIALS_DIRECTORY/lferraz-tailnet-ca-key" \
        -CAcreateserial \
        -CAserial ${certStateDir}/ca.srl \
        -out "$work_dir/${deviceName}.crt" \
        -days ${toString cfg.certificates.leafDays} \
        -sha256 \
        -extensions req_ext \
        -extfile "$work_dir/openssl.cnf"

      install -m 0644 -o root -g caddy "$work_dir/${deviceName}.crt" ${certFile}
      install -m 0640 -o root -g caddy "$work_dir/${deviceName}.key" ${certKeyFile}
    '';
  };
in {
  options.services.lferrazTailnetAccess = {
    enable = mkEnableOption "lferraz.dev tailnet DNS, local CA certificates, and port-subdomain proxying" // {default = true;};

    publicDomain = mkOption {
      type = types.str;
      default = "lferraz.dev";
      description = "Public suffix used for tailnet-local aliases.";
    };

    deviceName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      defaultText = "config.networking.hostName";
      description = "Tailscale MagicDNS device name for this machine.";
    };

    tailnetDomain = mkOption {
      type = types.str;
      default = "rudd-agama.ts.net";
      description = "Tailscale MagicDNS tailnet domain.";
    };

    baseHost = mkOption {
      type = types.str;
      readOnly = true;
      description = "Complete base hostname of the device within the network.";
    };

    dns.enable = mkEnableOption "CoreDNS lferraz.dev-to-MagicDNS aliasing" // {default = true;};
    proxy = {
      enable = mkEnableOption "Caddy port-subdomain reverse proxy" // {default = true;};
      idleCheckInterval = mkOption {
        type = types.ints.positive;
        default = 30;
        description = "Seconds between checks for idle on-demand aliases.";
      };
      aliases = mkOption {
        type = types.attrsOf (types.oneOf [
          (types.ints.between 1 65535)
          types.lines
          (types.submodule {
            options = {
              port = mkOption {
                type = types.ints.between 1 65535;
                description = "Local HTTP port to wait for and proxy to on 127.0.0.1.";
              };
              service = mkOption {
                type = types.nullOr (types.strMatching "[a-zA-Z0-9_@.:-]+[.]service");
                default = null;
                example = "ollama.service";
                description = "Systemd unit to start on demand; mutually exclusive with scripts. Disable its automatic activation separately.";
              };
              user = mkOption {
                type = types.nullOr (types.strMatching "[a-z_][a-z0-9_-]*");
                default = null;
                description = "Owner of a systemd user service; null selects the system manager. The user manager must already be running (login or linger).";
              };
              startScript = mkOption {
                type = types.nullOr types.lines;
                default = null;
                description = "Root shell script that starts the backend via a service manager. Use absolute command paths. Must be idempotent and exit after starting the service.";
              };
              stopScript = mkOption {
                type = types.nullOr types.lines;
                default = null;
                description = "Root shell script that stops the backend; required with startScript when idleTimeout is set.";
              };
              idleTimeout = mkOption {
                type = types.nullOr types.ints.positive;
                default = null;
                example = 900;
                description = "Seconds without requests before stopping; null disables idle shutdown. Open requests and WebSockets prevent shutdown.";
              };
              startupTimeout = mkOption {
                type = types.ints.positive;
                default = 60;
                description = "Maximum seconds for the start action and TCP readiness combined; failure returns HTTP 503.";
              };
              stopTimeout = mkOption {
                type = types.ints.positive;
                default = 30;
                description = "Maximum seconds for the stop action; failures are retried on the next idle check.";
              };
            };
          })
        ]);
        default = {};
        example = {
          node-red = 1880;
          ollama = {
            port = 11434;
            service = "ollama.service";
            idleTimeout = 900;
          };
          static = ''
            root * /srv/static
            file_server
          '';
        };
        description = ''
          Named service aliases to local ports or Caddy handler blocks. For example,
          `node-red = 1880` makes `node-red.${deviceName}.${publicDomain}` proxy
          to `127.0.0.1:1880`.

          A string value is inserted directly into the alias-specific `handle`
          block, after matching `<alias>.${deviceName}.${publicDomain}`.

          An attribute set starts a system/user service or custom script before
          proxying, with optional idle shutdown. Disable the backend's boot,
          login, socket and timer activation separately. Traffic must use this
          named alias to participate in startup and idle tracking. Each backend
          must have only one on-demand alias.
        '';
      };
    };

    certificates = {
      enable = mkEnableOption "tailnet-local certificate issuance and trust" // {default = true;};
      leafDays = mkOption {
        type = types.ints.positive;
        default = 825;
        description = "Validity, in days, for per-host certificates signed by the local CA.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.certificates.enable {
      services.machineBackups.directories = [
        {
          name = "tailnet-certificates";
          paths = [certStateDir];
          optional = true;
        }
      ];

      age.secrets.lferraz-tailnet-ca-key = {
        rekeyFile = ../../../secrets/lferraz-tailnet-ca.key;
        path = caKeyCredential;
        symlink = false;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      security.pki.certificateFiles = [caCert];

      environment.sessionVariables = systemTrustEnvironment;
      systemd.globalEnvironment = systemTrustEnvironment;

      environment.systemPackages = [issueCertificate];

      systemd.tmpfiles.rules = [
        "d ${certStateDir} 0750 root caddy - -"
        "d ${certDir} 0750 root caddy - -"
      ];

      systemd.services.lferraz-tailnet-certificate = {
        description = "Issue ${deviceName}.${publicDomain} certificate from the lferraz.dev tailnet CA";
        wantedBy = ["multi-user.target"];
        before = ["caddy.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe generateHostCertificate;
          LoadCredential = ["lferraz-tailnet-ca-key:${config.age.secrets.lferraz-tailnet-ca-key.path}"];
          RemainAfterExit = true;
        };
      };
    })

    (mkIf cfg.dns.enable {
      services.coredns = {
        enable = true;
        config = ''
          .:53 {
            bind 127.0.0.1 ${config.services.tailscale.interfaceName}
            errors
            log

            rewrite stop {
              name regex ^(?:.*[.])?([^.]+)[.]${regexPublicDomain}[.]$ {1}.${tailnetDomain}.
              answer auto
            }

            # Try Tailscale's resolver first, then NextDNS. Tailscale answers
            # SERVFAIL for names it has no upstream for and stops answering
            # while disconnected; both cases move on to the next server.
            forward . 100.100.100.100 ${lib.concatMapStringsSep " " (address: "tls://${address}") nextDnsServers} {
              tls_servername ${nextDnsServerName}
              policy sequential
              failover SERVFAIL REFUSED
            }
            cache 30
          }
        '';
      };

      # Tailscale Serve does not proxy UDP, so DNS is exposed directly on the
      # Tailscale interface. The shared tailscale.nix module marks that
      # interface as trusted in the firewall.
      systemd.services.coredns = {
        after = ["tailscaled.service" "network-online.target"];
        wants = ["tailscaled.service" "network-online.target"];
      };

      # Make this host's CoreDNS the primary resolver: ~. takes every name
      # away from DHCP-provided link DNS servers. lferraz.dev is listed too so
      # it stays exclusive to CoreDNS when Tailscale also claims ~. on its
      # link (exit node or overridden local DNS).
      services.resolved = {
        enable = true;
        settings.Resolve = {
          DNS = "127.0.0.1";
          Domains = ["~." "~${publicDomain}"];
        };
      };
    })

    (mkIf (cfg.proxy.enable && onDemandAliases != {}) {
      assertions =
        lib.concatLists (lib.mapAttrsToList (alias: target: [
            {
              assertion = (target.service != null) != (target.startScript != null);
              message = "Tailnet alias ${alias} must specify exactly one of service and startScript.";
            }
            {
              assertion = target.service == null || target.stopScript == null;
              message = "Tailnet alias ${alias}: stopScript cannot be combined with service.";
            }
            {
              assertion = target.user == null || target.service != null;
              message = "Tailnet alias ${alias}: user requires service; scripts run as root.";
            }
            {
              assertion = target.idleTimeout == null || target.service != null || target.stopScript != null;
              message = "Tailnet alias ${alias} needs stopScript for idle shutdown.";
            }
          ])
          onDemandAliases)
        ++ [
          {
            assertion = let
              ports = lib.mapAttrsToList (_: target: target.port) onDemandAliases;
            in
              builtins.length ports == builtins.length (lib.unique ports);
            message = "Tailnet on-demand aliases must use distinct backend ports to share one activity counter per backend.";
          }
          {
            assertion = let
              units =
                lib.mapAttrsToList (_: target: [target.user target.service])
                (lib.filterAttrs (_: target: target.service != null) onDemandAliases);
            in
              builtins.length units == builtins.length (lib.unique units);
            message = "Tailnet on-demand aliases must not manage the same systemd service more than once.";
          }
        ];

      systemd.services.lferraz-tailnet-on-demand = {
        description = "Start Tailnet HTTP backends on demand and stop them after inactivity";
        wantedBy = ["multi-user.target"];
        before = ["caddy.service"];
        serviceConfig = {
          ExecStart = "${lib.getExe onDemandPackage} ${onDemandConfig}";
          User = "root";
          Group = "caddy";
          RuntimeDirectory = "lferraz-tailnet-on-demand";
          RuntimeDirectoryMode = "0750";
          RuntimeDirectoryPreserve = "restart";
          UMask = "0077";
          Restart = "on-failure";
          RestartSec = 1;
        };
      };
      systemd.services.caddy = {
        after = ["lferraz-tailnet-on-demand.service"];
        wants = ["lferraz-tailnet-on-demand.service"];
      };
    })

    (mkIf cfg.proxy.enable {
      services.machineBackups.directories = [
        {
          name = "caddy-state";
          paths = [config.services.caddy.dataDir];
          optional = true;
        }
      ];

      assertions = [
        {
          assertion = cfg.certificates.enable;
          message = "services.lferrazTailnetAccess.proxy requires services.lferrazTailnetAccess.certificates.enable.";
        }
        {
          assertion = lib.all validAliasName aliasNames;
          message = "services.lferrazTailnetAccess.proxy.aliases names must be lowercase, non-numeric DNS labels.";
        }
      ];

      services.lferrazTailnetAccess.baseHost = "${deviceName}.${publicDomain}";

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [80 443];

      services.caddy = {
        enable = true;
        virtualHosts = let
          extraConfig = ''
            ${aliasProxyBlocks}

            @port_local header_regexp port_local Host ${portLocalHostRegexp}
            handle @port_local {
              ${localPortProxyHandler "{re.port_local.1}"}
            }

            @port header_regexp port Host ${portHostRegexp}
            handle @port {
              ${portProxyHandler "localhost:{re.port.1}"}
            }

            handle {
              header Content-Type "text/html; charset=utf-8"
              respond `<!doctype html>
            <html lang="en">
              <head>
                <meta charset="utf-8">
                <title>${deviceName}.${publicDomain}</title>
              </head>
              <body>
                <h1>${deviceName}.${publicDomain}</h1>
                <p>Use http://&lt;port&gt;.${deviceName}.${publicDomain} or https://&lt;port&gt;.${deviceName}.${publicDomain} to proxy a local HTTP service on this device.</p>
                <p>Use http://&lt;port&gt;-local.${deviceName}.${publicDomain} or https://&lt;port&gt;-local.${deviceName}.${publicDomain} when the service expects Host/Origin localhost:&lt;port&gt;.</p>
            ${aliasListHtml}
              </body>
            </html>` 200
            }
          '';
        in {
          tailnet = {
            hostName = "https://${tailnetHost}";
            serverAliases = [
              # "http://${tailnetHost}"
              # "http://*.${deviceName}.${publicDomain}"
              "https://*.${deviceName}.${publicDomain}"
              # "http://${deviceName}.${publicDomain}"
              "https://${deviceName}.${publicDomain}"
            ];
            listenAddresses = [tailnetHost];
            useACMEHost = null;
            extraConfig = ''
              tls ${certFile} ${certKeyFile}
              ${extraConfig}
            '';
          };
          tailnet-no-tls = {
            inherit extraConfig;
            hostName = "http://${tailnetHost}";
            serverAliases = [
              "http://*.${deviceName}.${publicDomain}"
              "http://${deviceName}.${publicDomain}"
            ];
            listenAddresses = [tailnetHost];
            useACMEHost = null;
          };
        };
      };

      systemd.services.caddy = {
        after = ["lferraz-tailnet-certificate.service" "tailscaled.service"];
        requires = mkIf cfg.certificates.enable ["lferraz-tailnet-certificate.service"];
        wants = ["tailscaled.service"];
        serviceConfig = {
          ExecStartPre = "${lib.getExe config.services.tailscale.package} wait";
          Restart = mkForce "always";
        };
      };
    })
  ]);
}
