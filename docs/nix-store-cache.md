# Shared remote Nix cache

[Project overview](../README.md) · [Secrets](secrets.md)

`nixos/nix-settings.nix` enables `nixos/modules/nix-store-cache.nix` on all four NixOS
machines, through the workstation baseline or `servers/common.nix`. It replaces the SSH
peer cache; host SSH keys remain in use for normal SSH and agenix. The remote server is
[Cubby](https://git.fryuni.dev/Fryuni/cloudflare-nix-cache).

## Configuration and authentication

The shared `services.nixStoreCache` settings expose `endpoint`, `tokenFile`,
`uploadConcurrency` (a positive integer, default `1`), and `maxQueueAgeSeconds` (a
positive integer, default `604800`, or seven days). Nix and Cachix connect directly to
`https://nix-cache.fryuni.dev` for substitution and uploads; there is no local proxy.
Agenix decrypts `secrets/nix-store-cache-token` to a root-owned, mode `0600` runtime
file containing only the write token. On every machine, the daemon startup hook
generates `/run/nix-store-cache/netrc` (mode `0600`, directory `0700`) from that token
and the endpoint hostname; `nix.settings.netrc-file` points to this generated file.
Credentials never enter the Nix store. HTTPS is required except for localhost testing.
Netrc credentials are hostname-scoped, not path-scoped, so use a dedicated cache
hostname.

Determinate Nix overrides `netrc-file` after including NixOS settings. On those
machines, the daemon startup hook also appends any existing `/nix/var/determinate/netrc`
to the generated netrc. The daemon receives that path through `NIX_CONFIG`. This
intentionally avoids `authentication.additionalNetrcSources`, whose merged file is
world-readable. The private copy is refreshed on daemon restart, including after changes
to Determinate credentials. Upstream Nix machines use the generated netrc through
`nix.settings.netrc-file`. The independent upload service explicitly uses the agenix
file on all machines; it does not depend on the daemon's private runtime file.

The generated netrc contains `machine nix-cache.fryuni.dev`, `login ""`, and
`password "<Cubby WRITE_TOKEN>"`. The empty login preserves Cubby's Basic authentication
convention. Normal users can request substitution through the daemon without reading the
credential. Direct user `nix copy` commands need their own credentials; remote uploads
are not delegated to the daemon. The configured Cubby public key verifies cache
signatures; global signature verification remains enabled and the substituter is not
marked `trusted=true`. Treat remote write access and the cache signing key as authority
to supply executable store paths to every machine.

## Upload queue

The system post-build hook only enqueues locally built outputs as direct GC-root
symlinks in the root-only `/nix/var/nix/gcroots/nix-store-cache` directory; it performs
no network operations. Duplicate outputs coalesce without refreshing their queue age.
`nix-store-cache-upload.service` drains this persistent queue with at most
`uploadConcurrency` concurrent `cachix --host https://nix-cache.fryuni.dev push main`
processes. Cachix uses multipart uploads to split large NARs into smaller requests
rather than exceeding the hosting platform's single-request limit. At startup, the
service reads the agenix token file directly and exports it as `CACHIX_AUTH_TOKEN`; the
token is never embedded in a store path or command-line argument. Uploads include
reference closures so dependencies need not finish separate uploads first. The root
service reads the local store directly, independently of the build daemon. Successful
uploads remove their queue entries; failures log a warning and retain entries for retry.
Each drain pass is followed by a five-second pause, and systemd restarts an interrupted
worker. Pending entries survive service restarts and reboots and keep their closures
alive through garbage collection until uploaded or expired. Inspect failures with
`journalctl -u nix-store-cache-upload.service`. Substituted paths do not run the hook;
existing store paths are not automatically backfilled. Other configured substituters
remain available during a cache outage.

## Manual uploads

Use `nix run .#cache-push -- INSTALLABLE_OR_PATH [...]` to manually add outputs to that
same queue, including outputs previously uploaded or purged from the remote cache. The
cache module also installs `nix-store-cache-push` for ordinary user shells. Both
commands use `common/nix-store-cache.nix`, shared with the post-build hook. Installable
references build as the invoking user with `nix build --out-link ... --print-out-paths`,
using temporary registered GC roots; existing store paths and symlinks such as
`./result` are resolved and temporarily rooted without building their derivations. Paths
inside a store object, such as `./result/bin/tool`, queue the containing store object.
Temporary roots retain every selected object while later targets build, paths are
validated, or sudo waits for authentication, and remain until the command creates the
queue's root-owned GC-root symlinks. An exit trap removes temporary roots after the
handoff or on failure; result links in the working directory are left untouched. Uploads
remain asynchronous, and an already-pending entry keeps its original age.

```bash
nix run .#cache-push -- nixpkgs#hello
nix run .#cache-push -- ./result /nix/store/HASH-package
nix-store-cache-push '.#legacyPackages.x86_64-linux.openssl^*'
```

## Queue expiration

`nix-store-cache-expire.timer` runs an independent hourly cleanup, including catch-up
after downtime. Entries at least `maxQueueAgeSeconds` old are removed based on the
symlink modification time, unaffected by upload retries or GC reads. Expiration can lag
the age limit by roughly one timer interval while the host is running. Cleanup removes
only queue roots, never store paths; subsequent normal GC (including
`nh clean all -K 8h`) can reclaim paths not protected by other roots. The `8h`
generation-retention setting does not itself expire these queue roots. Expired outputs
are no longer guaranteed to reach the cache. Cleanup continues if the uploader is
stopped or stalled, but disabling the entire cache module also removes its expiration
timer: clear any remaining queue symlinks when decommissioning the module.

## Metrics

`services.nixStoreCache.metrics` publishes queue telemetry through the Prometheus node
exporter's textfile collector. It defaults to following
`services.prometheus.exporters.node.enable`, so `note`, `loem`, and `rpi3` collect
metrics while `gce-automation`, which runs no exporter and has no Tailnet identity, does
not. `nix-store-cache-metrics.timer` fires every `metrics.interval` (default `30s`, with
`AccuracySec=1s` so systemd does not coalesce it past the 15s scrape interval) and
publishes `nix-store-cache.prom` into `metrics.textfileDirectory` (default
`/var/lib/prometheus-node-exporter/textfile`) by atomic rename. That directory is
world-readable because the node exporter runs unprivileged; the queue itself stays
root-only. The exporter is scraped by the host `vmagent`, which remote-writes to `loem`.
Because `nixos/modules/networking/tailscale.nix` stamps `instance` and `host` with the
hostname through `global.relabel_configs`, series from different machines stay distinct.

Five series are published. `nix_store_cache_queue_pending` and
`nix_store_cache_queue_oldest_seconds` are gauges derived from the queue directory on
each collection. `nix_store_cache_uploads_total`,
`nix_store_cache_upload_failures_total`, and `nix_store_cache_expired_total` are
counters persisted under `/var/lib/nix-store-cache`. The upload and expiry scripts
increment them under `flock` and publish each value by rename, so concurrent upload
workers cannot lose an increment and the collector cannot observe a partial value.
Counter updates are best effort: a telemetry failure never fails an upload or a sweep.
Counters survive reboots and reset only when that state directory is cleared, which
appears as an ordinary counter reset to `rate` and `increase`.

The [loem metrics stack](services.md#metrics) includes a Grafana dashboard for these
series at `servers/loem/metrics/dashboards/nix-store-cache.json`.

## Credential maintenance

1. Configure the endpoint in `nixos/nix-settings.nix`; its hostname is used
   automatically in the generated netrc.
2. Use `agenix -e secrets/nix-store-cache-token` with an authorized master identity to
   edit the raw write token, optionally followed by a newline. Do not add netrc fields
   or quotes; the runtime generator handles netrc escaping.
3. Run `just rekey` and stage the updated encrypted source and host-specific rekeyed
   files.
4. For `gce-automation`, first assign a stable hostname and register its SSH host public
   key with the existing host-key/rekey workflow. That image currently has no host
   identity and uses agenix-rekey's dummy recipient; its secrets cannot decrypt until
   provisioned.
5. Build the affected NixOS configuration before applying it. Deploy the updated secret
   after rotation and restart both `nix-daemon.service` and
   `nix-store-cache-upload.service` to ensure all transfers use the new credentials.

## Validation

The cache module and command have dedicated checks:

```bash
nix build .#checks.x86_64-linux.nix-store-cache-module --no-link
nix build .#checks.x86_64-linux.nix-store-cache-command --no-link
```
