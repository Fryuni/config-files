{pkgs, ...}: let
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
