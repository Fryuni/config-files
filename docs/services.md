# Hosted services and Tailnet access

[Project overview](../README.md) · [Architecture](architecture.md)

These notes cover selected services on `loem` and the shared private networking layer.
The active service imports are in `servers/loem/default.nix`; the Nix modules are the
source of truth for the full service configuration.

## Forgejo and Actions runners

`servers/loem/forgejo.nix` runs a local Forgejo instance backed by the host PostgreSQL
service, with repositories and LFS data persisted under `/var/lib/forgejo`. Forgejo
listens only on loopback: the existing Cloudflare Tunnel publishes HTTPS at
`git.fryuni.dev`, while Tailscale Serve exposes only the built-in SSH service as
`git.rudd-agama.ts.net:22` inside the Tailnet. The same module continues to run the
independent Forgejo Actions runners registered with the local Forgejo, Codeberg, and
git.gay, configured through the first-party nixpkgs `services.forgejo-runner` module.

All three Actions runners expose `nix:host` for workflows using `runs-on: nix`. They
share an explicit host package list that puts Nix and the workflow tools on each runner
service's PATH; host jobs use the host Nix daemon and store.

The `pkgs.forgejo` overlay builds both the server and frontend from
[Fryuni's fork](https://git.fryuni.dev/Fryuni/forgejo), pinned to a commit on its
`forgejo` branch.

See [Forgejo runner setup](../servers/loem/forgejo-actions.md) for registration,
credential rotation, runner state, and host-job operation.

## GitHub Actions runners

`servers/loem/github-actions.nix` also runs GitHub Actions through
`services.github-runners`. The compact scope-to-credential map in
`servers/loem/github-actions-runners.nix` creates one registration per personal
repository (`Fryuni/t3code` initially) and one per organization (`fryuni-testorg`
initially). Each registration has its own service and disk-backed workspace, supports
host Nix and Docker jobs, and accepts `runs-on: [self-hosted, nix, loem]`. Each adds
capacity for one concurrent job. Credentials use agenix when the corresponding encrypted
source exists, with root-only provisioned files as a bootstrap fallback. See
[GitHub runner setup](../servers/loem/github-actions.md) for credential provisioning,
adding repositories, and validation.

## Executor

`servers/loem/executor.nix` runs the
[self-hosted Executor](https://executor.sh/docs/hosted/docker) MCP server as a Docker
container through `virtualisation.oci-containers`, using the Docker backend already
configured by `nixos/modules/docker.nix`. The image is pinned by multi-arch index digest
rather than tracking `:latest`, because `oci-containers` only pulls when the reference
is absent locally. A single container process serves the typed API, the streamable-HTTP
MCP endpoint, authentication, QuickJS code execution, and the web console, backed by a
libSQL file; no external database or worker is involved. Its published port is bound to
`127.0.0.1:4788` because Docker publishes ports past the NixOS firewall, so the tailnet
Caddy proxy is the only reachable entrypoint, exposing the `executor` alias at
`https://executor.loem.lferraz.dev`. State lives in a root-owned bind mount at
`/var/lib/executor`, holding `data.db` plus the session secret and the master key for
stored secrets that the container generates on first boot; `EXECUTOR_WEB_BASE_URL`
matches the proxied URL so browser logins are not rejected as invalid-origin, and
`EXECUTOR_ALLOW_LOCAL_NETWORK` stays disabled to keep sandboxed code away from the
Tailnet and this host's loopback services.

## Metrics

`servers/loem/metrics/` runs VictoriaMetrics on loopback with one month of retention,
publishes it inside the Tailnet as `victoriametrics.rudd-agama.ts.net` through Tailscale
Serve, and runs Grafana on loopback with provisioned datasources and dashboards. The
VictoriaMetrics datasource pins `uid = "victoriametrics"` so provisioned dashboards can
reference it without depending on a generated identifier.
`servers/loem/metrics/dashboards/nix-store-cache.json` charts the remote cache upload
queue for the whole fleet: pending entries and the oldest pending entry, paths sent to
the cache over the last 24 hours and in total, a per-host breakdown, and failed or
expired entries. It is filterable by host and reads the
[shared Nix cache metrics](nix-store-cache.md#metrics).

## Tailnet access

`nixos/modules/networking/tailnet-access.nix` supplies private DNS, local CA
certificates, and Caddy routes for named aliases and numeric port hostnames. Aliases can
also start a system service, a user service, or a custom script before proxying to a
local port, with optional shutdown after inactivity. These aliases enable a root-owned
`lferraz-tailnet-on-demand` helper behind a Caddy-accessible Unix socket. It waits for
readiness, tracks active HTTP and WebSocket connections, and checks idle time
periodically. Backend boot/login activation must be disabled in the owning service
configuration. Configuration examples and lifecycle details are in
[On-demand Tailnet aliases](../common/docs/tailnet-on-demand.md). The
`tailnet-access-module` check validates the module, generated Caddy routes, and the
helper's startup, proxying, concurrency, and idle shutdown behavior.

The shared Tailscale module uses the upstream `nixpkgs-master` package, with updates
managed through that flake input.

The notebook uses `us-chi-wg-301.mullvad.ts.net` as its Tailscale exit node, configured
declaratively through `services.tailscale.extraSetFlags` in
`nixos/notebook/default.nix`.
