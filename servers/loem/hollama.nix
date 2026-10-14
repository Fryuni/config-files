{config, ...}: let
  port = 3080;
  # Seed a connection once per browser, retaining subsequent user changes.
  bootstrap = ../../common/hollama;
in {
  virtualisation.oci-containers.containers.hollama = {
    # Hollama 0.36.0, pinned to the multi-arch index digest.
    image = "ghcr.io/fmaclen/hollama@sha256:5353564fb9f6675556ec99f1011fbcc9bc52f4cd7023a9debd8c69db5bc55081";
    ports = ["127.0.0.1:${toString port}:4173"];
    extraOptions = [
      "--read-only"
      "--cap-drop=ALL"
      "--security-opt=no-new-privileges"
    ];
  };

  systemd.services."${config.virtualisation.oci-containers.backend}-hollama" = {
    wants = ["cli-proxy-api.service"];
    after = ["cli-proxy-api.service"];
  };

  # The UI has no database or volumes: sessions and settings live in localStorage.
  services.lferrazTailnetAccess.proxy.aliases.chat = ''
    @cli_proxy_api path /v1 /v1/*
    handle @cli_proxy_api {
      reverse_proxy 127.0.0.1:8317
    }

    @bootstrap path /
    handle @bootstrap {
      root * ${bootstrap}
      header Cache-Control "no-store"
      file_server
    }

    handle {
      reverse_proxy 127.0.0.1:${toString port}
    }
  '';
}
