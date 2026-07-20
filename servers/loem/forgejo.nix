{
  config,
  pkgs,
  ...
}: let
  domain = "git.fryuni.dev";
  httpPort = 3333;
  sshPort = 2222;
in {
  imports = [../../nixos/modules/forgejo-runner.nix];

  age.secrets = {
    codeberg-actions-token = {
      rekeyFile = ../../secrets/loem/codeberg-forgejo-actions-runner-token;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    gitgay-actions-token = {
      rekeyFile = ../../secrets/loem/gitgay-forgejo-actions-runner-token;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  services.forgejo = {
    enable = true;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = domain;
        ROOT_URL = "https://${domain}/";
        SSH_DOMAIN = "git.rudd-agama.ts.net";
        SSH_USER = "git";
        BUILTIN_SSH_SERVER_USER = "git";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = httpPort;
        START_SSH_SERVER = true;
        SSH_LISTEN_HOST = "127.0.0.1";
        SSH_LISTEN_PORT = sshPort;
      };
      repository = {
        ENABLE_PUSH_CREATE_USER = true;
        ENABLE_PUSH_CREATE_ORG = true;
      };
      security.GLOBAL_TWO_FACTOR_REQUIREMENT = "all";
      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;
    };
  };

  services.cfTunnel.ingress.${domain} = "http://localhost:${toString httpPort}";

  services.forgejo-runner = {
    package = pkgs.forgejo-runner;
    instances = {
      codeberg = {
        enable = true;
        settings.container.docker_host = "automount";
        labels = [
          "ubuntu-24.04:docker://ghcr.io/catthehacker/ubuntu:act-24.04"
          "ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04"
          "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-24.04"
          "docker:docker://ghcr.io/catthehacker/ubuntu:act-24.04"
        ];
        connections.codeberg = {
          url = "https://codeberg.org/";
          uuid = "d1716ab7-66c0-4b19-beb3-0ce1d1f84360";
          tokenFile = config.age.secrets.codeberg-actions-token.path;
        };
      };
      gitgay = {
        enable = true;
        settings.container.docker_host = "automount";
        labels = [
          "ubuntu-24.04:docker://ghcr.io/catthehacker/ubuntu:act-24.04"
          "ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04"
          "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-24.04"
          "docker:docker://ghcr.io/catthehacker/ubuntu:act-24.04"
        ];
        connections.codeberg = {
          url = "https://git.gay/";
          uuid = "4d34b7ae-b5fd-4a1f-abaa-bd361704e760";
          tokenFile = config.age.secrets.gitgay-actions-token.path;
        };
      };
    };
  };

  services.tailscale.serve.services.git.endpoints = {
    "tcp:22" = "tcp://localhost:${toString sshPort}";
  };
}
