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
Serve, and runs Grafana on loopback with provisioned datasources and dashboards.
The private Caddy alias serves Grafana at `https://grafana.loem.lferraz.dev`, using
the existing Tailnet DNS and CA. Grafana's domain, root URL, and secure cookies
match that HTTPS URL. Grafana has no separate Tailscale Serve service; the
Grafana-specific proxy preserves the browser's Host and Origin headers for CSRF
and Grafana Live checks. The generic numeric-port proxy rewrites Host and is
unsuitable for authenticated Grafana browser operations. The VictoriaMetrics
service remains independent of Loem and collectors keep writing
to `http://victoriametrics.rudd-agama.ts.net/api/v1/write` after a host migration.
The VictoriaMetrics datasource pins `uid = "victoriametrics"` so provisioned dashboards can
reference it without depending on a generated identifier.
`servers/loem/metrics/dashboards/nix-store-cache.json` charts the remote cache upload
queue for the whole fleet: pending entries and the oldest pending entry, paths sent to
the cache over the last 24 hours and in total, a per-host breakdown, and failed or
expired entries. It is filterable by host and reads the
[shared Nix cache metrics](nix-store-cache.md#metrics).

Additional versioned dashboards in the same directory cover fleet CPU, memory,
storage, RAID and pressure; Tailnet paths and per-service traffic; scrape and
ingestion health plus hosted service activity; and notebook battery and thermals.
`bare-metal-hardware.json` adds server hardware temperatures with sensor names,
hardware-reported temperature margins and alarm flags, CPU workload and frequency,
core and package throttling, and Linux software RAID. It selects Loem initially;
its host inventory discovers machines reporting hwmon temperatures without battery
metrics, and All expands that inventory. Sensors without name metadata are retained.
Loem currently provides no fan RPM or SMART series, so those require additional
instrumentation before they can be charted.
The current summary stats in these new fleet, Tailnet, pipeline, notebook and
bare-metal dashboards use instant queries with a two-minute source-sample age
limit. Collection gaps produce unavailable data instead of retaining a historical
healthy value. Historical charts retain their selected time range separately.
`automated-backups.json` charts complete restore point ages, independent push
heartbeats, operation results and durations, source and newly added packed bytes,
Storage Box quota, integrity and maintenance ages, coverage findings, queued
notifications, and isolated restore evidence. Hosts are discovered from configured
backup peer relationships; restore panels filter the restored `source_host` and
identify the observing `host` in their legends. Hosts with no reports are
visible as missing telemetry. The backup runner posts Prometheus text directly to
`http://victoriametrics.rudd-agama.ts.net/api/v1/import/prometheus` after jobs and
every five minutes; this does not require a scrape endpoint or Pushgateway.
See [backup telemetry](backups.md#pushed-backup-telemetry) for state, retries and
freshness semantics.
They use the live `host`, `job`, `service`, and `path` labels and keep lifetime
counters separate from current error rates. The local Loem scrape jobs also collect
VictoriaMetrics (`8428`), vmagent (`8429`), Soft Serve (`23233`), cloudflared
(`20241`), and Caddy's admin metrics (`2019`). Exporters stay on loopback. See the
[metrics coverage audit](metrics-audit.md) for observed coverage and remaining gaps.

The `metrics-automation` user has the Editor role for browser dashboard work.
The separate `repository-automation` service account has an Editor API token.
Both credentials are stored as one JSON document in
`secrets/loem/grafana-automation-credentials`, encrypted to the repository's
normal recipients and rekeyed for Loem. Its root-only runtime path is
`/run/agenix/grafana-automation-credentials`. Use `.browser.username` and
`.browser.password` for a browser login, or `.service_account.token` for a Bearer
API request. Decrypt directly into the consuming process; avoid printing the
document or placing credentials in command arguments. Service accounts cannot
sign in to the UI. Account identities and password/token hashes are persisted in
Grafana's database and included in its service backup; the encrypted secret
records their credentials, rather than automatically creating accounts on a
fresh empty database. Recreate the accounts and re-encrypt/rekey the document if
restoring the database is not possible. Revoke and replace the token when rotating
credentials.

### Datasource UID migration

When adopting the pinned `victoriametrics` UID on an existing Grafana database,
Grafana 13 can fail during provisioning if the datasource with the same name has
an old generated UID. The observed failure was
`Datasource provisioning error: data source not found`. With Grafana stopped,
back up its SQLite database, reconcile that existing datasource row's UID, and
update matching `permission.scope` (`datasources:uid:<uid>`) and
`permission.identifier` rows. Audit stored dashboard and resource definitions for
old references as well; Grafana 13 stores dashboards in the unified resource
tables. Preserve the existing datasource and database instead of deleting their
state. This migration was performed on Loem on 2026-10-11 and startup and scrape
health were verified afterward.

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
