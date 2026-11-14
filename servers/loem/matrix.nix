{
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "matrix.lferraz.com";
  tuwunel-port = 3340;

  element-web = pkgs.element-web.override {
    # See https://github.com/element-hq/element-web/blob/develop/config.sample.json
    conf = {
      default_theme = "dark";
    };
  };
in {
  services.matrix-tuwunel = {
    enable = true;
    settings.global = {
      server_name = "lferraz.com";
      port = [tuwunel-port];

      trusted_servers = ["matrix.org" "constellatory.net" "tchncs.de" "mozilla.org"];

      allow_registration = false;

      ip_source = "cf_connecting_ip";
      well_known.client = "https://${domain}";
      well_known.server = "${domain}:443";

      allow_public_room_directory_over_federation = true;
    };
  };

  services.machineBackups.directories = lib.mkIf config.services.matrix-tuwunel.enable [
    {
      name = "matrix-tuwunel";
      paths = ["/var/lib/${config.services.matrix-tuwunel.stateDirectory}"];
      units = [{name = "tuwunel.service";}];
      # Stopping Tuwunel through the whole upload made Cloudflare answer 502
      # (seen by Element as CORS failures); link RocksDB and media while stopped,
      # then restart before upload.
      hardlinkSnapshot = true;
      stopForSnapshot = true;
    }
  ];

  services.cfTunnel.ingress = {
    "${domain}" = "http://localhost:${toString tuwunel-port}";
  };

  services.lferrazTailnetAccess.proxy.aliases = {
    matrix = tuwunel-port;
    element = ''
      root * ${element-web}
      file_server
    '';
  };
}
