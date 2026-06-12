{
  config,
  lib,
  ...
}: let
  cfg = config.services.cfTunnel;
in {
  options.services.cfTunnel = {
    tunnel-id = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Cloudflare Tunnel ID to use for exposing services publicly.
      '';
    };

    token-secret = lib.mkOption {
      type = lib.types.pathInStore;
      description = ''
        Encrypted agenix-rekey secret containing the Cloudflare Tunnel token.
      '';
    };

    ingress = lib.mkOption {
      type = with lib.types;
        attrsOf (
          either str (
            submodule (
              _: {
                options = {
                  inherit originRequest;

                  service = lib.mkOption {
                    type = with lib.types; nullOr str;
                    default = null;
                    description = ''
                      Service to pass the traffic.

                      See [Supported protocols](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/local-management/ingress/#supported-protocols).
                    '';
                    example = "http://localhost:80, tcp://localhost:8000, unix:/home/production/echo.sock, hello_world or http_status:404";
                  };

                  path = lib.mkOption {
                    type = with lib.types; nullOr str;
                    default = null;
                    description = ''
                      Path filter.

                      If not specified, all paths will be matched.
                    '';
                    example = "/*.(jpg|png|css|js)";
                  };
                };
              }
            )
          )
        );
      default = {};
      description = ''
        Ingress rules.

        See [Ingress rules](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/local-management/ingress/).
      '';
      example = {
        "*.domain.com" = "http://localhost:80";
        "*.anotherone.com" = "http://localhost:80";
      };
    };
  };

  config = lib.mkIf (cfg.tunnel-id != null) {
    age.secrets.cloudflare-tunnel-credentials-file.rekeyFile = cfg.token-secret;

    services.cloudflared.enable = true;
    services.cloudflared.tunnels.${cfg.tunnel-id} = {
      # nixpkgs' cloudflared module requires credentialsFile, but this wrapper
      # uses dashboard tunnel tokens. The systemd service below passes the token
      # with TUNNEL_TOKEN_FILE, which cloudflared prefers over credentials-file.
      credentialsFile = config.age.secrets.cloudflare-tunnel-credentials-file.path;
      default = "http_status:404";
      inherit (cfg) ingress;
    };

    systemd.services."cloudflared-tunnel-${cfg.tunnel-id}" = let
      tunnel = config.services.cloudflared.tunnels.${cfg.tunnel-id};
      certFile =
        if tunnel.certificateFile != null
        then tunnel.certificateFile
        else config.services.cloudflared.certificateFile;
    in {
      serviceConfig.LoadCredential = lib.mkForce (
        ["token:${config.age.secrets.cloudflare-tunnel-credentials-file.path}"]
        ++ lib.optional (certFile != null) "cert.pem:${certFile}"
      );
      environment.TUNNEL_TOKEN_FILE = "%d/token";
    };
  };
}
