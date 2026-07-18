{
  config,
  pkgs,
  ...
}: {
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

  services.tailscale.serve.services.gitea.endpoints = {
    "tcp:22" = "tcp://localhost:2222";
    "tcp:443" = "tls-terminated-http://localhost:3333";
  };
}
