# Metrics coverage audit

Audit date: 2026-10-11. Evidence comes from the repository configuration, read-only
requests to Loem's running metrics endpoints, VictoriaMetrics instant queries,
backup status, and CPA Manager Plus's SQLite schema. Observed values below describe
the audit time, rather than continuing health guarantees.

## Current ingestion

Before this change, VictoriaMetrics reported five scrape targets:

| Host | Job | Observed status |
| --- | --- | --- |
| `loem` | `node` | Healthy, approximately 997 samples per scrape |
| `note` | `node` | Healthy, approximately 1,206 samples per scrape |
| `loem` | `tailscale` | Healthy, approximately 33 samples per scrape |
| `note` | `tailscale` | Healthy, approximately 27 samples per scrape |
| `loem` | `grafana` | Failed, zero samples; Grafana's service was failed |

Grafana was repaired during this work by reconciling its provisioned datasource
UID and matching permissions. Its database health check passed, the existing
`grafana` scrape returned `up = 1`, and all four new dashboards were imported and
inspected in `agent-browser`. The new jobs below still require configuration
activation, as this repository reserves activation for the user.

The shared [Tailscale module](../nixos/modules/networking/tailscale.nix) sets a
15-second scrape interval and identifies each machine with `host` and `instance`.
Remote write uses the device-independent Tailscale Service
`victoriametrics.rudd-agama.ts.net`. The [Loem metrics
module](../servers/loem/metrics/default.nix) stores one month of data and provisions
the `victoriametrics` Grafana datasource.

[Raspberry Pi configuration](../servers/rpi3/default.nix) enables vmagent, but
`rpi3` was absent from the observed host inventory. Check whether that configuration
has been deployed and whether the Pi is running and can reach the remote-write
service; the inventory alone does not establish its state.

## Existing endpoints covered by this change

These endpoints were already running and returned Prometheus data, but were not
being ingested. The updated Loem scrape configuration covers them. Check ingestion
after activating that configuration; reachable endpoints alone do not create
stored series.

| Service | Local endpoint | Verified useful metrics |
| --- | --- | --- |
| VictoriaMetrics | `http://127.0.0.1:8428/metrics` | `vm_rows_inserted_total`, `vm_data_size_bytes`, `vm_free_disk_space_bytes`, `vm_storage_is_read_only`, `vm_http_request_errors_total`, `vm_slow_queries_total` |
| vmagent | `http://127.0.0.1:8429/metrics` | `vmagent_remotewrite_pending_data_bytes`, `vmagent_remotewrite_push_failures_total`, `vmagent_remotewrite_packets_dropped_total`, `vmagent_remotewrite_bytes_sent_total`, `vm_promscrape_scrapes_failed_total`, `vm_promscrape_targets` |
| Soft Serve | `http://127.0.0.1:23233/metrics` | `soft_serve_cli_commands_total`, `soft_serve_git_upload_pack_total`, `soft_serve_git_upload_pack_seconds_total`, `soft_serve_ssh_public_key_auth_total` |
| Cloudflare Tunnel | `http://127.0.0.1:20241/metrics` | `cloudflared_tunnel_ha_connections`, `cloudflared_tunnel_total_requests`, `cloudflared_tunnel_request_errors`, `cloudflared_tunnel_response_by_code`, `cloudflared_proxy_connect_latency_bucket` |
| Caddy | `http://127.0.0.1:2019/metrics` | `caddy_config_last_reload_successful`, `caddy_config_last_reload_success_timestamp_seconds`, `caddy_reverse_proxy_upstreams_healthy` |

Useful labels include VictoriaMetrics insertion `type="promremotewrite"`, storage
size `type`, vmagent target `status="up"` or `"down"`, Cloudflare response
`status_code`, and Soft Serve `repo`, `command`, and authentication `allowed`.
vmagent intentionally masks remote-write URL labels as `1:secret-url`.

Cloudflare Tunnel had four connected edge sessions. vmagent's pending remote-write
queue, dropped packets, and push failures were zero. These values are suitable for
baseline checks, while counter rates show current errors.

Caddy's upstream gauges do not establish that an application is ready when active
health checks are absent. Its HTTP traffic metrics were not enabled at audit time.

## Useful dashboards from available data

| View | Questions answered | Existing metric families |
| --- | --- | --- |
| Fleet resources | Which machine is under load, short of memory or disk space, or blocked on IO? | `node_cpu_seconds_total`, `node_load1`, `node_memory_MemAvailable_bytes`, `node_memory_MemTotal_bytes`, `node_filesystem_avail_bytes`, `node_filesystem_size_bytes`, `node_disk_*`, `node_pressure_*`, `node_hwmon_temp_celsius` |
| Storage health | Is Loem's RAID degraded? Are queues or filesystems unhealthy? | `node_md_degraded`, `node_md_disks`, `node_md_state`, `node_filesystem_device_error`, `node_filesystem_readonly`, `node_btrfs_*` |
| Bare-metal hardware | Which sensor is hot, how close is it to its reported limits, and is the CPU throttling? | `node_hwmon_temp_celsius`, `node_hwmon_temp_max_celsius`, `node_hwmon_temp_crit_celsius`, `node_hwmon_temp_crit_alarm_celsius`, `node_hwmon_sensor_label`, `node_hwmon_chip_names`, `node_thermal_zone_temp`, `node_cpu_core_throttles_total`, `node_cpu_package_throttles_total`, `node_cpu_scaling_frequency_hertz` |
| Tailnet traffic | Is traffic direct or relayed? Which portable service is receiving it? | `tailscaled_inbound_bytes_total`, `tailscaled_outbound_bytes_total`, `tailscaled_outbound_dropped_packets_total`, `tailscaled_serve_inbound_bytes_total`, `tailscaled_serve_outbound_bytes_total`, `tailscaled_health_messages` |
| Monitoring and services | Are scrapes succeeding, writes queued, storage healthy, tunnels connected, and Git traffic active? | `up`, `scrape_duration_seconds`, `scrape_samples_scraped`, plus the newly configured endpoint families above |
| Nix cache | Are store paths uploading, retrying, expiring, or remaining queued? | `nix_store_cache_queue_pending`, `nix_store_cache_queue_oldest_seconds`, `nix_store_cache_uploads_total`, `nix_store_cache_upload_failures_total`, `nix_store_cache_expired_total` |

Loem's `md126` and `md127` arrays both had two active members, no failed members,
and no degradation. Both machines' Nix cache queues were empty. Note's historical
upload failure counter was high, so use `rate()` or `increase()` to distinguish
recent failures from old retries. The [existing Nix cache
dashboard](../servers/loem/metrics/dashboards/nix-store-cache.json) already covers
that pipeline.

Tailscale `path` values were `direct_ipv4`, `direct_ipv6`, `derp`,
`peer_relay_ipv4`, and `peer_relay_ipv6`. Service labels were `svc:git`,
`svc:git-ss`, and `svc:victoriametrics`. Both Loem and Note have hardware temperature
data. Battery telemetry is specific to Note and is absent on Loem.
Note reported learned battery capacity of approximately 1.818 Ah against a
3.948 Ah design capacity, or 46% health; the notebook dashboard makes this
hardware signal visible.

The additional [bare-metal hardware dashboard](../servers/loem/metrics/dashboards/bare-metal-hardware.json)
shows Loem's CPU package and four core sensors, both chipset hwmon sensors, and two
kernel thermal zones. Sensor-name joins preserve readings without metadata.
Loem reports CPU high limits of 80 °C and critical limits of 100 °C; the dashboard
computes margins from the actual limits rather than assuming these values for
every host. Critical alarm metrics are 0/1 flags despite their `_celsius` suffix.
Core and package throttle events are shown separately to avoid counting one
incident twice. No fan RPM, SMART, IPMI, RAPL, or EDAC metrics were present on Loem
when this dashboard was added.

Exclude zero-sized RAM filesystems and container mounts from disk percentages, and
avoid counting `/` and its `/nix/store` bind mount twice. Filter shared `vm_*`,
`process_*`, and `go_*` families by `job` to identify their owning service. Missing
series should remain visibly unavailable, rather than being turned into a healthy
zero.

## Priority gaps and recommendations

Backup telemetry below is now configured. The remaining instrumentation is
recommended and has not been enabled.

### Backup freshness and restore confidence — instrumented on 2026-10-12

Backups already record enough telemetry in `/var/lib/machine-backups/state.json`:
`lastComplete`, `observedComplete`, `health`, `capacity`, `lastIntegrityCheck`,
`lastMaintenance`, and, after a rehearsal, `lastRestoreRehearsal`. See the [backup
runner](../common/backups/runner.py) and [backup operations](backups.md).

At audit time Loem's last services restore point was captured at 00:34 UTC, more
than the monitor's two-hour freshness limit. The recorded services failure was a
Nix capture error: libgit2 rejected `/home/lotus/ZShutils` because the repository
was not owned by the user performing that operation. The repository-status failure
reported a competing local backup operation, so it should not be interpreted as a
confirmed outage of the remote backup repository. The latest home completion was
12:15 UTC, the integrity check completed at 03:40 UTC, and measured storage quota
usage was 3.04%. Note's backup freshness and the inventory also reported warnings.

The runner now pushes `machine_backup_*` metrics directly to VictoriaMetrics's
Prometheus import endpoint through the portable Tailnet service, after operations
and on a separate five-minute timer. This replaces the initial textfile collector
recommendation with the requested push model. Telemetry heartbeat, repository
contact and measurement times remain distinct from restore point capture times.
Complete data freshness keeps the existing two-hour service and twelve-hour home
limits. Persisted operation counts retain failures through delivery outages;
byte summaries are recorded only for completed uploads. Peer observations retain
their observer identity, and configured clients with no telemetry are discoverable.

The [automated backup dashboard](../servers/loem/metrics/dashboards/automated-backups.json)
also covers quota, integrity/maintenance, coverage, notifications and isolated
restore evidence. Rehearsal gauges use verification time and disclose partial
selections and unverified application startup. See [push semantics and metric
families](backups.md#pushed-backup-telemetry).

A manual state-only push on 2026-10-12 populated 33 real Loem series through
`victoriametrics.rudd-agama.ts.net`. It exposed the still-overdue services restore
point, current home completion, 3.06% occupied quota and the existing coverage
warning. No production backup or rehearsal was run for this verification, and
no NixOS configuration was applied. Automatic pushes require activation on each
client; fresh run summaries and rehearsal results populate their panels afterward.

### PostgreSQL and Forgejo

PostgreSQL has no exporter. Add `services.prometheus.exporters.postgres` on
`127.0.0.1:9187`, connect through `/run/postgresql`, and scrape its `/metrics`.
Use a dedicated monitoring role with `pg_monitor` and access to the intended
databases. Track database availability, connections, transactions, deadlocks,
database size, locks, and table maintenance. The exporter supports a
[non-superuser monitoring role](https://github.com/prometheus-community/postgres_exporter#running-as-non-superuser).
Validate actual collector names against the installed exporter before adding
dashboard queries.

Forgejo's `/metrics` on `127.0.0.1:3333` currently returns 404. Enable
`services.forgejo.settings.metrics.ENABLED` and scrape that endpoint. Because
Cloudflare Tunnel forwards the same listener, configure a runtime-backed metrics
`TOKEN` and matching vmagent bearer token, or explicitly block `/metrics` on the
public route. Forgejo documents [metrics enablement and token
authentication](https://forgejo.org/docs/latest/admin/config-cheat-sheet/#metrics-metrics).
Its optional issue-by-label and issue-by-repository metrics can help track project
backlogs; enable them only where the resulting series are useful.

### Application availability and Caddy requests

The node exporter currently has no `node_systemd_*` series. Enable its `systemd`
collector with an include filter for managed services, including Grafana, Forgejo,
PostgreSQL, Matrix, Soft Serve, CLIProxyAPI, CPA Manager Plus, Executor, the registry,
and the Actions runners. This gives a direct view of failed units without another
exporter; the [node exporter collector
reference](https://github.com/prometheus/node_exporter#collectors) describes the
available collector and filters. For scheduled backups, an idle unit is normal;
use completion telemetry to assess success.

Add HTTP probes for meaningful health endpoints to distinguish a running process
from a working application. Executor, Matrix, CLIProxyAPI, and CPA Manager Plus
currently return 404 for `/metrics`; T3 Code returns its HTML application shell.
These are not scrape targets until an actual exporter or metrics handler exists.

Enable Caddy's global `metrics` option to measure request rates, errors, latency,
and response sizes. Its [metrics documentation](https://caddyserver.com/docs/metrics)
also supports `per_host` metrics and describes the admin scrape endpoint. Caddy
instruments multiple middleware handlers for one request, so choose a handler when
aggregating instead of summing all handlers. If using `per_host`, preserve the
virtual hostname under a separate label: the shared scraper already uses `host`
for the machine, and normal label collision handling may expose the original value
as `exported_host`.

### AI usage and Actions runners

CPA Manager Plus already collects AI usage, but it is absent from VictoriaMetrics.
Read-only schema inspection of `/var/lib/cpa-manager-plus/usage.sqlite` found
`usage_events`, `usage_dashboard_hourly_rollups`, and pricing rollups with request
counts, success/failure counts, input/output/reasoning/cache tokens, latency, model,
provider, and service tier. Raw events also contain time-to-first-token.

Export bounded aggregates for request rates, errors, token throughput, cache ratio,
latency, and ingestion freshness. Reuse the application's pricing calculations
when exposing cost; a flat token sum misses cache, context-length, and service-tier
rules. Exclude authentication identifiers and raw requests from metric labels.
Rolling-window totals should be gauges, and counters need persistent monotonic
accounting if underlying usage records can be archived or deleted. This requires
a small exporter or application change; there is no usable `/metrics` endpoint
today.

The three Forgejo runners have no job telemetry in VictoriaMetrics. The [GitHub
runner registration map](../servers/loem/github-actions-runners.nix) is currently
empty, so no GitHub runners are enabled through that module. Start with Forgejo
runner unit state, then collect queue time, busy capacity,
job duration, outcomes, and last successful job from the owning CI system's API or
an explicit collector. A runner's listening cache port is not evidence of a
Prometheus endpoint. Host-level CPU and IO cannot explain which workflow is slow.

### Docker, registry, and drive health

Docker has no metrics listener. A follow-up can set
`virtualisation.docker.daemon.settings."metrics-addr" = "127.0.0.1:9323"` and
scrape `/metrics`. Docker's [native metrics](https://docs.docker.com/engine/daemon/prometheus/)
cover the daemon; per-container resource metrics require separate instrumentation
such as cAdvisor. Start with the native listener before adding another agent.

The registry's application listener on `127.0.0.1:3379` does not expose `/metrics`.
Configure `services.dockerRegistry.extraConfig.http.debug` with a dedicated
loopback address, `prometheus.enabled = true`, and `prometheus.path = "/metrics"`,
then scrape the debug listener. Distribution's [configuration
reference](https://github.com/distribution/distribution/blob/main/docs/content/about/configuration.md#debug)
documents this separate endpoint.

RAID health is already ingested, but SMART error counters and SSD wear are not.
A drive-health exporter would add predictive disk signals that RAID state cannot
provide. Notebook GPU workload and VRAM usage are also absent; only pursue those
if they answer a concrete workload question.

## Verification after activation

In Grafana Explore, confirm `up` for every configured job, inspect scrape duration
and sample counts, and check that each dashboard query returns the expected labels.
For the remote-write path, watch vmagent queue size and push failures alongside
VictoriaMetrics ingestion rate. The service's DNS name should stay
`victoriametrics.rudd-agama.ts.net` when its host changes; exporters remain local
to their machines.
