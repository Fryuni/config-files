# Executor self-hosted MCP server (https://executor.sh/docs/hosted/docker)
{config, ...}: let
  port = 4788;
  stateDir = "/var/lib/executor";
  alias = "executor";
  webBaseUrl = "https://${alias}.${config.networking.hostName}.${config.services.lferrazTailnetAccess.publicDomain}";
in {
  # /data holds data.db plus the generated BetterAuth session secret and the
  # master key for stored secrets, so it must survive restarts and upgrades.
  # Match the image's nonroot UID/GID, including previously root-owned files.
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 65532 65532 - -"
    "Z ${stateDir} - 65532 65532 - -"
  ];

  virtualisation.oci-containers.containers.executor = {
    # Pinned to the multi-arch index digest of :latest (v1.6.11) as of 2026-11-03. Re-pin with:
    #   docker buildx imagetools inspect ghcr.io/usefulsoftwareco/executor-selfhost:latest --format '{{.Manifest.Digest}}'
    image = "ghcr.io/usefulsoftwareco/executor-selfhost@sha256:ea8b4d1019cc00c81cb4236d8edc07a12ac75ef465593b89ae652c0800cd33c1";

    # Docker publishes ports past the NixOS firewall, so bind to loopback and
    # let Caddy be the only reachable entrypoint.
    ports = ["127.0.0.1:${toString port}:4788"];

    volumes = ["${stateDir}:/data"];

    environment = {
      # Required behind TLS: browser logins are rejected as invalid-origin
      # unless this matches the URL the browser actually uses.
      EXECUTOR_WEB_BASE_URL = webBaseUrl;

      # Keep sandboxed code off the tailnet and this host's other services.
      EXECUTOR_ALLOW_LOCAL_NETWORK = "false";
    };
  };

  services.machineBackups.directories = [
    {
      name = "executor";
      paths = [stateDir];
      units = [{name = "${config.virtualisation.oci-containers.backend}-executor.service";}];
    }
  ];

  services.lferrazTailnetAccess.proxy.aliases.${alias} = port;
}
