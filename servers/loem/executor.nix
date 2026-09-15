# Executor self-hosted MCP server (https://executor.sh/docs/hosted/docker)
{config, ...}: let
  port = 4788;
  stateDir = "/var/lib/executor";
  alias = "executor";
  webBaseUrl = "https://${alias}.${config.networking.hostName}.${config.services.lferrazTailnetAccess.publicDomain}";
in {
  # /data holds data.db plus the generated BetterAuth session secret and the
  # master key for stored secrets, so it must survive restarts and upgrades.
  # The image runs as root, so a bind mount needs no ownership fixups.
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 root root - -"
  ];

  virtualisation.oci-containers.containers.executor = {
    # Pinned to the multi-arch index digest of :latest as of 2026-09-15. Re-pin with:
    #   docker buildx imagetools inspect ghcr.io/rhyssullivan/executor-selfhost:latest --format '{{.Manifest.Digest}}'
    image = "ghcr.io/rhyssullivan/executor-selfhost@sha256:200315d519a8c19685de05e88aa9a3cf1e1cb9869a2b0aecf604f6ebf47c6ea1";

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

  services.lferrazTailnetAccess.proxy.aliases.${alias} = port;
}
