{
  cloudflareTunnelModule,
  lib,
  pkgs,
}: let
  tunnelId = "76fe45e2-d197-49bf-aaf2-e6b3dc2dd2f6";
  tokenSecret = pkgs.writeText "cloudflare-tunnel-token.age" "encrypted token fixture";

  evaluated = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    inherit pkgs;
    modules = [
      cloudflareTunnelModule
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
            };
          }));
        };
      })
      {
        system.stateVersion = "26.05";

        services.cfTunnel = {
          tunnel-id = tunnelId;
          token-secret = tokenSecret;
          ingress."example.test" = "http://127.0.0.1:8080";
        };
      }
    ];
  };

  cfg = evaluated.config;
  service = cfg.systemd.services."cloudflared-tunnel-${tunnelId}";

  configJson = builtins.toJSON {
    cloudflaredEnabled = cfg.services.cloudflared.enable;
    credentialSource = cfg.services.cloudflared.tunnels.${tunnelId}.credentialsFile;
    environment = service.environment;
    execStart = service.serviceConfig.ExecStart;
    loadCredential = service.serviceConfig.LoadCredential;
  };
in
  pkgs.runCommand "cloudflare-tunnel-module-check" {
    nativeBuildInputs = [pkgs.jq];
    inherit configJson;
  } ''
    printf '%s\n' "$configJson" > config.json

    jq -e '.cloudflaredEnabled == true' config.json
    jq -e '.credentialSource == "/run/agenix/cloudflare-tunnel-credentials-file"' config.json
    jq -e '.loadCredential == ["token:/run/agenix/cloudflare-tunnel-credentials-file"]' config.json
    jq -e '.loadCredential | any(startswith("credentials.json:")) | not' config.json
    jq -e '.environment.TUNNEL_TOKEN_FILE == "%d/token"' config.json
    jq -e '.environment.TUNNEL_EDGE_IP_VERSION == "4"' config.json
    jq -e '.execStart | contains("cloudflared tunnel --config=")' config.json

    touch "$out"
  ''
