# Backups and recovery

Status: implemented for `loem` and `note`; activation and production recovery
rehearsals are separate rollout steps. The shared repository, dedicated SSH
identity, and separate Gotify application token have been provisioned. The
readiness checklist below records the checks needed before relying on production
restore points.

## Confirmed requirements

- Use restic for periodic incremental backups.
- Protect the user's home directory and persistent service state on `loem` and
  `note`. Other machines are outside the initial rollout.
- Use the Hetzner Storage Box at `u688316.your-storagebox.de` as the backup target.
- Use one shared restic repository for cross-machine deduplication, with
  independent restore points for each machine and backup scope. See
  [ADR-0001](adr/0001-shared-backup-repository.md).
- Authenticate backup jobs with a dedicated shared SSH keypair, managed through
  agenix. Enrolling another machine distributes that same private key through
  the host-rekey workflow; it does not require another Storage Box key entry.
  See [ADR-0002](adr/0002-shared-backup-access-identity.md).

A restic backup records a new restore point; it does not synchronize one
machine's files onto another machine's backup tree. The same absolute filename
can have different content in each host's restore points. Deleting a source file
changes future restore points for that source, while retained older points and
the other host's history remain available. Repository maintenance must preserve
data referenced by any retained restore point.

## Recovery decisions

- Recover a failed machine by reinstalling NixOS from this repository and
  restoring user files, persistent service state, and required identities.
- Target at most one hour of service data loss and six hours of home-directory
  data loss while machines are running and connected. Scheduling, capture time,
  transfer time, and failures must be considered before claiming these targets
  are met.
- Start with a one-year history horizon. Revisit it using measured deduplication,
  compression, storage growth, and cost; this is a provisional target rather
  than an unconditional promise. Keep every restore point for seven days, daily
  points for 30 days, weekly points for 12 weeks, and monthly points for 12 months,
  independently for each machine and backup scope.
- Rely on Storage Box snapshots for recovery from a compromised source deleting
  repository data. The user does not want special source-side deletion controls
  for this scenario. Daily provider snapshots retaining ten captures are
  accepted, including the potentially larger data-loss window after repository
  deletion. The user has configured snapshot contents to be hidden from within
  the Box; the actual automatic snapshot schedule has not been independently
  verified.
- Allow up to one minute of interruption per service per hourly backup where a
  verified online capture is unavailable. Capture locally, restart the service,
  then upload. Validate that this budget is achievable; failure handling must
  restore service availability without reporting an incomplete capture as a
  successful backup.
- Run notebook backups at low priority while awake and connected, including on
  battery. Do not wake the notebook. Catch up after resume or reconnection.
  The user reports that the notebook is on almost all the time.
- Store backup credentials through agenix. The user already has an externally
  stored agenix decryption key and independent Storage Box access, and will keep
  backup recovery keys in an external password manager as well. Backup jobs use
  the dedicated backup access identity, not user login keys or an SSH agent.
- Use Gotify for failures and overdue backups, with a separate backup
  application/token. Retry transient failures every 15 minutes. Alert when the
  latest complete service backup is over two hours old, or a home backup is over
  12 hours old; report credential, capture, and storage-full failures immediately.
  Send a recovery notification when healthy again. Each machine checks the
  other's backup freshness; partial backups never count as success.
- `loem` owns shared weekly retention cleanup and repository checks, including a
  rotating quarter of stored data read each week. Coordinate maintenance with
  both machines' backup and catch-up runs through locking and bounded retry.
- Warn at 70% Storage Box usage and escalate at 85%, counting space retained by
  provider snapshots. Review actual growth after the first month. Changes to
  retention or purchased capacity remain manual.
- Provide a manual recovery runbook and measure recovery time. Before declaring
  the setup ready, restore representative home files and each service's required
  data in isolation. Plan a quarterly recovery rehearsal; no fixed maximum
  recovery time is promised before a realistic restore has been measured.

## Data classification and exclusions

The approved exclusions are:

- `/home/lotus/.cache`
- `/home/lotus/.npm/_cacache`
- `/home/lotus/.npm/_logs`
- `/home/lotus/.cargo/registry`
- `/home/lotus/.cargo/target`
- Every directory named `.direnv`, at any depth in any backed-up source
- `/var/lib/cli-proxy-api/logs/main.log`
- `/var/lib/cli-proxy-api/logs/main-*.log`

Preserve downloads, repositories and uncommitted work, credentials, application
history, and persistent service data. Additional exclusions require a concrete
classification; do not infer disposability from a generic filename or directory
name.

CLIProxyAPI's full AI request and response exchanges form the **AI exchange
corpus**, retained for future model fine-tuning. Preserve that corpus. Ordinary
diagnostic logs can be excluded, but a directory name such as `logs` or a `.log`
extension does not establish that a file is disposable.

Read-only investigation of the pinned CLIProxyAPI source and runtime metadata
identified request exchanges under `/var/lib/cli-proxy-api/logs`, including
`v1-messages-*.log`, `v1-chat-completions-*.log`, `v1-responses-*.log`, other
endpoints, and error exchanges. The approved diagnostic exclusions are only
`main.log` and `main-*.log` in that directory. Preserve unknown request families
by default.
No request payloads were read during this investigation.

The current log-directory size cleanup is disabled; ordinary request exchanges
have no discovered automatic age limit. Enabling the size cleaner later could
delete corpus files as well as diagnostics. A file remaining in the source can
remain in new restore points indefinitely despite the one-year history policy;
after source deletion, eventual expiration of its last retained restore point
can remove it from backups too. This is the accepted behavior: the user will
delete exchanges after placing them elsewhere, and their old backup copies may
then expire normally. This backup protects the machines; it does not provide a
separate permanent corpus archive or add source cleanup.
[Pinned request writer](https://github.com/Fryuni/CLIProxyAPI/blob/6b763383c43ac26af5890e3b1f32717598812b8d/internal/logging/request_logger_writer.go),
[log-directory cleanup](https://github.com/Fryuni/CLIProxyAPI/blob/6b763383c43ac26af5890e3b1f32717598812b8d/internal/logging/log_dir_cleaner.go).

The named home cache paths and `/home/lotus/ZShutils/.direnv` were observed on
`loem`; the `.direnv` exclusion intentionally extends beyond that example.
Arbitrary `logs`, `target`, `.venv`, or `node_modules` directory names throughout
home are not automatically excluded. Application state under `.t3`, `.hermes`,
`.omp`, `.no-mistakes`, and `.local` remains included except for the explicit
exclusions above.

## Coverage and recovery inputs

The implementation must maintain an explicit manifest of source paths, capture
methods, credentials, and restore steps. Reconcile it with actual services and
data before declaring coverage complete, and when services, databases, or
container volumes change. An unclassified persistent path is a coverage gap,
not an implicit exclusion.

For both machines, include:

- `/home/lotus`, subject to the approved exclusions.
- Hourly service captures of the relevant state within home, so those services
  meet the service target independently of the six-hour home schedule.
- `/opt/tailscale-inbox`, SSH host identities under `/etc/ssh`, and persistent
  Tailscale, Tailnet certificate, and Caddy state under `/var/lib/tailscale`,
  `/var/lib/lferraz-tailnet`, and `/var/lib/caddy`, where present.
- The flake source and lock file, encrypted secret sources and rekeyed outputs,
  and recovery metadata for database/package versions, ownership, and paths.
- A recoverable copy of the locked Nix input sources needed to bootstrap without
  `loem`'s Forgejo. Several inputs are hosted on that same server. Restoring a
  machine must not first require its unavailable services to fetch its build
  inputs. Preserve these selected recovery inputs without backing up the entire
  regenerable Nix store.

Additional `loem` coverage comprises every PostgreSQL database and cluster
globals; Forgejo; Soft Serve; Tuwunel including media; Executor; CLIProxyAPI and
the AI exchange corpus; CPA Manager Plus; the Docker registry; Grafana;
VictoriaMetrics; and the configured Forgejo runner state. Home service coverage
includes T3 Code, Hermes, Syncthing, and the discovered no-mistakes daemon.
Preserve generated application keys alongside their databases.

On `note`, reconcile the declared Node-RED, T3 Code, Hermes, and Syncthing state
with runtime paths. Inventory persistent mounts, Docker volumes, and mutable
machine configuration such as NetworkManager connection credentials before
signing off coverage. Database files copied live by the general home job are not
a substitute for the dedicated consistent service captures.

## Verified findings

- The flake defines `note`, `loem`, `gce-automation`, and `rpi3`. Definitions alone
  do not prove deployment; only `note` and `loem` are in the initial rollout.
- `loem` runs Forgejo/PostgreSQL, Matrix Tuwunel, Soft Serve, CLIProxyAPI,
  CPA Manager Plus, Executor, a Docker registry, and VictoriaMetrics, with Grafana
  configured as well. Service state spans databases, repository/upload files,
  and generated secrets. See [hosted services](services.md) and the active
  imports in [the loem module](../servers/loem/default.nix).
- Read-only runtime discovery on `loem` found PostgreSQL databases beyond
  Forgejo, including `agentsview`, `honcho`, `litellm`, `paperclip`, `scopegate`,
  and test databases. A Forgejo-only database dump would not provide complete
  coverage.
- Some services keep their state in `/home/lotus`, including user applications
  and the notebook's Node-RED. Their service state needs the hourly target even
  though the surrounding home directory has a six-hour target. The service modules
  declare these captures; notebook runtime coverage still needs reconciliation.
- Read-only runtime discovery found SQLite-backed state for T3 Code, Hermes,
  and the `no-mistakes` daemon under the user's home, plus Syncthing state and
  identity files. CLIProxyAPI's state directory occupies about 38 GiB; the user
  identifies the bulk of this as valuable AI exchanges, not disposable logs.
- `/opt/tailscale-inbox` is outside both home and `/var/lib`; coverage must be
  explicit. Runtime Docker volumes and imperative state also need inventory.
- `note` and `loem` use ext4 roots; no source filesystem snapshot facility is
  declared. Database consistency cannot be assumed from copying live files.
- On `loem`, Tuwunel, Soft Serve, and VictoriaMetrics state paths resolve into
  `/var/lib/private`. Restic source selection must capture the real directories,
  rather than only the symlinks. CPA Manager Plus and Executor have generated
  encryption/authentication keys beside their databases.
- The notebook's runtime inventory remains unverified: read-only SSH discovery
  passed host-key checking but failed authentication. Its Nix declarations are
  available for design, but do not establish all actual files and services.
- Agenix host identities and the user's rekey identity are needed for recovery;
  see [secrets and host identities](secrets.md). A recovery path must avoid
  depending on credentials available only inside the backup being restored.
- A read-only SSH probe on 2026-10-10 succeeded against the Storage Box using
  the existing key and strict host-key checking on port 23. It reported 1.0 TiB
  total capacity, 128 KiB used, and 1.0 TiB available. No snapshot entries were
  visible in `/home/.zfs/snapshot`. The user subsequently confirmed that snapshot
  visibility is disabled in the dashboard; the listing does not establish
  whether automatic snapshots are configured.
- An existing Gotify notification integration is declared in
  [software-raid.nix](../nixos/modules/software-raid.nix). Reusing the notification
  destination for backup failures is accepted, using a separate backup application.

Hetzner documents Storage Box snapshots as read-only through file access, with
automatic snapshot rotation and storage consumption within the Box's quota.
Consequently, deletion recovery depends on a clean snapshot remaining available;
pruning restic data may not immediately free the corresponding Box space while
provider snapshots retain it. Provider snapshots are also on the same Storage
Box. See [Hetzner snapshot documentation](https://docs.hetzner.com/storage/storage-box/snapshots/).

The documented built-in snapshot schedule supports daily, weekly, or monthly
captures; an hourly provider snapshot plan has not been established. Snapshot
management uses Console/API access, separate from ordinary SSH file access.
The ordinary hourly service-backup target therefore must not be conflated with
the rollback window available after repository deletion. See
[creating Storage Box snapshots](https://docs.hetzner.com/storage/storage-box/getting-started/creating-snapshots/).

The shared repository deduplicates across machines and across restore points.
Host and backup-scope labels distinguish histories, but do not impose access
controls: either machine's repository credentials can decrypt both machines'
data. See [restic backup documentation](https://restic.readthedocs.io/en/stable/040_backup.html)
and [repository encryption](https://restic.readthedocs.io/en/stable/070_encryption.html).

## Capture strategy and validation

Use application-supported online captures where verified. Otherwise prepare an
incremental local copy and coordinate the final capture with the affected
service, within the accepted interruption budget. Preserve ownership, modes,
symlinks, and relevant ACLs/xattrs. A service capture succeeds only when its
database, associated files, and required keys form a recoverable set.

Implementation must validate these mechanisms against the installed versions:

- PostgreSQL supports consistent online dumps per database; cluster roles and
  tablespaces need separate coverage. Dumps taken independently are not one
  simultaneous cluster-wide snapshot.
  [PostgreSQL 17 documentation](https://www.postgresql.org/docs/17/app-pgdump.html)
- Forgejo requires coordination across database and file storage. On the
  current ext4 setup, coordinate a native database dump and prepared file capture
  while writes are paused; service downtime must not extend through remote upload.
  [Forgejo backup guidance](https://forgejo.org/docs/v16.0/admin/upgrade/#backup)
- Tuwunel 1.9.3 offers online RocksDB backups/checkpoints, but media needs
  separate coverage and checkpoint completion must be verified.
  [Versioned Tuwunel guidance](https://github.com/matrix-construct/tuwunel/blob/v1.9.3/docs/backups.md)
- Soft Serve stores a SQLite database together with repositories; capturing
  SQLite online alone does not coordinate the repository files; capture both
  coherently within the interruption budget.
  [Soft Serve documentation](https://github.com/charmbracelet/soft-serve)
- Executor's pinned source documents a libSQL issue with opening a second
  connection that can unlink WAL/SHM files. An unverified generic online backup
  connection must not be assumed safe; clean stop and local capture is a
  candidate under the accepted service-interruption budget.
  [Pinned database implementation](https://github.com/UsefulSoftwareCo/executor/blob/2dc399e51094fccd2a45103a38d77179c6d648ff/apps/host-selfhost/src/db/self-host-db.ts)
- VictoriaMetrics supports online snapshots materialized through `vmbackup`
  to a local staging directory; its snapshot directory contains internal
  symlinks and should not simply be archived as ordinary files.
  [vmbackup documentation](https://docs.victoriametrics.com/victoriametrics/vmbackup/)
- CLIProxyAPI creates unique request filenames but writes directly to the final
  filename, so a `.log` name does not prove that capture is complete. Transient
  request/response parts also disappear during normal operation. A completion
  or quiescence strategy is required. Prepare bulk copies while running and
  validate only a bounded final capture while quiesced; copying the whole
  38 GiB corpus from scratch while stopped is not an established viable method.

## Shared-repository operation

Stable host names (`loem`, `note`) and stable backup-scope tags will identify
restore points. Apply retention separately to each host/scope combination so one
machine's recent backup never replaces the other's retention allowance. Backup
runs may share stored chunks without sharing a source directory tree.

The locked NixOS restic module can express separate capture jobs and a standalone
maintenance job. `loem` is the sole maintenance owner; locking and bounded retry
must cover overlap with either host's scheduled or catch-up runs. Complete
backups remain distinguishable from partial attempts during both freshness
monitoring and retention selection.

A partial restic snapshot must not reset the last-success indicator. Restic exit
code 3 means some source data was unreadable; the default NixOS unit treats it as
failure. Maintenance must retain known-complete recovery points even if partial
ones exist. Uploads initially carry the `machine-backup` and `home` or `services` tags.
Only exit-zero uploads receive the additional `complete` tag; freshness and
normal retention select that tag. Interrupted uploads or a failed tagging step
remain candidates and cannot replace a complete restore point.

The accepted retention wording uses elapsed windows from each host/scope's most
recent restore point: all points within 7 days, daily within 30 days, weekly
within 84 days, and monthly within 1 year. It is not a legal deletion deadline;
an offline machine's history must not age out merely because the other machine
continues backing up. Restic's `--keep-within-*` semantics support these windows.
[Retention and grouping](https://restic.readthedocs.io/en/stable/060_forget.html#removing-snapshots-according-to-a-policy)

Source services stopped during preparation must restart immediately after local
capture, including on capture failure. Restarting only in the NixOS module's
post-backup cleanup would keep them stopped throughout upload and violate the
accepted downtime policy.

## Declaring service state

Backup declarations belong in the module that defines the service and its state
path. `services.machineBackups.directories` is a list that Nix concatenates across
modules. Plain directories use the file-capture protocol by default:

```nix
services.machineBackups.directories = lib.mkIf cfg.enable [
  {
    name = "example-service";
    paths = [cfg.stateDirectory];
    excludes = ["/cache" "/logs/diagnostic-*.log"];
    units = [{name = "example-service.service";}];
  }
];
```

Exclusions use rsync patterns relative to each registered source. The service
module owns their classification. `.direnv` remains a global exclusion at every
depth. Shared absolute exclusions, such as user cache paths, use
`services.machineBackups.exclude`.

Set `kind = "sqlite"` when the directory needs SQLite's native backup protocol.
Capture-specific settings such as writer suspension and unit discovery stay with
that declaration. Set `scopes = ["home" "services"]` for application state that
must appear in both schedules; the home job excludes those live paths from its
ordinary file scan and substitutes their consistent captures.

Home Manager exposes the same options through
`nix-home/modules/machine-backups.nix`. Its service modules register configured
home or XDG paths. User unit records specify `type = "user"`; aggregation supplies
the enrolled user's username and UID. Machine configuration selects enrollment,
repository policy, the protected home, peer monitoring, and maintenance ownership.
An embedded Home Manager user's declarations are selected automatically. `note`
uses the standalone `homeConfigurations."lotus@note"` output and explicitly passes
its backup declarations through `services.machineBackups.homeManager`.

Native captures use `services.machineBackups.captures.<name>` so dependent modules
can contribute settings to the same capture. `postgresql.nix` defines the native
PostgreSQL dump and its tool dependency; `forgejo.nix` adds its database,
repositories, and dependent units to `captures.postgresql.coordinated`. This keeps
the database and repository capture coordinated while keeping Forgejo's paths in
its own module. VictoriaMetrics declares its native snapshot alongside its
storage configuration. Service modules also declare native tool dependencies
through `extraPackages`, additional natively covered paths through a capture's
`coveredPaths`, and any regenerable-state or parent-directory classifications
under `inventory`.

List registrations require explicit names, unique across directory and native
registrations. Supported capture and unit fields are typed: misspelled settings
and incomplete native captures fail Nix validation instead of silently losing
consistency safeguards.
The runtime inventory still checks live systemd state directories and container
mounts, and alerts on unclassified state; it does not silently enroll a new
service or infer that its files can be copied consistently.

## Operation

The shared [NixOS module](../nixos/modules/machine-backups.nix) installs
`machine-backup` and root-owned jobs on `loem` and `note`. Each service module
registers its own persistent paths, exclusions, and consistency settings. The
engine consumes those declarations without looking up particular services or
checking their enable flags.
The generated configuration contains paths and public connection information,
with credentials read from agenix runtime files. Staging and monitoring state
are under `/var/lib/machine-backups`, mode `0700`.

| Job | Schedule (UTC) | Purpose |
| --- | --- | --- |
| `machine-backup-services` | Every hour | Consistent service data and recovery inputs |
| `machine-backup-home` | 00:00, 06:00, 12:00, 18:00 | Home files and consistent application captures |
| `machine-backup-monitor` | Every 15 minutes | Mutual freshness, capacity, coverage, queued notifications |
| `machine-backup-maintain` | Sunday 03:30, on `loem` | Retention, prune, structure check, rotating data check |
| `machine-backup-rehearsal-reminder` | First day of each quarter, on `loem` | Reminder to perform isolated recovery rehearsals |

Calendar timers catch up when a machine returns. Jobs use low CPU/I/O priority,
do not wake the notebook, and can run on battery. A local lock serializes capture,
upload, and maintenance; monitoring has a separate lock so a long upload cannot
hide stale data. Restic repository locks coordinate both hosts, with a bounded
15-minute lock wait. Transient failures retry after 15 minutes; permanent failures
wait for intervention and generate alerts. Never unlock an active operation. Capacity monitoring compares available quota
with the configured full Box size, including space unavailable because of retained
snapshots. Verify it against the Console during rollout and monthly review; Hetzner
recommends Console/API values for authoritative accounting.
[Available disk space](https://docs.hetzner.com/storage/storage-box/available-disk-space/).

Manual commands after applying the configuration:

```bash
sudo systemctl start machine-backup-services.service
sudo systemctl start machine-backup-home.service
sudo machine-backup backup --scope home
sudo machine-backup backup --scope services
sudo machine-backup status
sudo machine-backup monitor
sudo machine-backup maintain --dry-run  # loem only
sudo machine-backup restic -- snapshots --host loem --tag machine-backup,complete
journalctl -u machine-backup-services -u machine-backup-home -u machine-backup-monitor
systemctl list-timers 'machine-backup-*'
```

Direct backups print timestamped progress to stderr: repository checks, each named
local capture and its duration, scanning/upload counts and bytes, and snapshot
completion. Restic progress updates arrive every five seconds. A 15-second
heartbeat reports the current phase and elapsed time even when a capture or remote
operation is silent; it shows that the wrapper is still waiting, without claiming
that the underlying operation is advancing. The same messages appear in the
systemd journal for scheduled jobs. Stdout retains the final JSON completion record.

The wrapper uses the configured repository password and only the dedicated
SSH identity, disables the agent and connection sharing, and pins the Box's
host keys. Administrative restic commands use that same SFTP connection on port 22;
capacity monitoring uses the extended SSH service on port 23 to run `df`.
The shared repository is
`sftp://u688316@u688316.your-storagebox.de:22/restic`, version 2, with restic's
repository compression. Its empty structural check passed at provisioning.
No production snapshots are implied by initialization.

The dedicated public key is enrolled on the Box; existing authorized entries
were preserved. Its fingerprint is
`SHA256:O01rhYQMwG9wbRHCWRTdLVuFTXZyuXVRSo9dcilH1ag`.
Hetzner's pinned host-key fingerprints are
`SHA256:EMlfI8GsRIfpVkoW1H2u0zYVpFGKkIMKHFZIRkf2ioI` (RSA, port 22) and
`SHA256:XqONwb1S0zuj5A1CDxpOSuD2hnAArV1A3wKY7Z3sdgM` (Ed25519, port 23),
verified against the [published host keys](https://docs.hetzner.com/storage/storage-box/general/#ssh-host-keys).
SSH and SFTP on port 23 were tested with only the recovered backup private key.
On 2026-10-10, a read-only SFTP probe on port 22 passed strict host-key checking
with that same identity and listed `restic/config`, confirming its enrollment.
Port 22 requires the public key to be enrolled in RFC4716 format as well as the
OpenSSH format used by port 23. To add both formats while preserving existing
authorized keys, use an authenticated administrative connection:

```bash
ssh -p 23 u688316@u688316.your-storagebox.de install-ssh-key < common/ssh/storagebox-backup.pub
```

After changing the authorized key, verify SFTP access on port 22 with the dedicated
backup identity before rollout.
[Hetzner key enrollment](https://docs.hetzner.com/storage/storage-box/ssh-keys/add-ssh-keys/).

The encrypted sources are `secrets/storagebox-backup-ssh-key`,
`secrets/restic-backup-password`, and
`secrets/restic-backup-gotify-token`. All three are rekeyed for both hosts. Run
`bash common/backups/provision-gotify.sh` to provision/rotate and test the separate
Gotify application token and encrypt it directly, then `just rekey` and stage the
host outputs. The helper uses hidden local input and retains no plaintext token.
Before that source exists, the module accepts a root-only bootstrap token at
`/var/lib/machine-backups/credentials/gotify-token`; undelivered notifications
stay queued. The initial separate application token was supplied through that helper and
its test notification succeeded.
[Gotify application authentication](https://gotify.net/api-docs).

Keep the password, SSH private key, external agenix recovery identity, and
independent Box administrative access in the external recovery vault. Recover
secrets through agenix locally; do not put plaintext values in shell arguments,
Git, or the Nix store. Future clients import the module, register their host key
for agenix-rekey, and enable it with their coverage and monitoring peer. They
receive the shared SSH identity without another Storage Box authorization change.
Choose only one maintenance owner.

## Capture layout and consistency

[Capture preparation](../common/backups/capture.py) finishes before
[the runner](../common/backups/runner.py) uploads. Large file trees are preseeded
while services are running; only stop, final incremental copy, and restart consume
the service interruption budget. Exceptions and timeouts request service restart.
Services that were already inactive are left inactive. Benchmark the initial
preseed separately; it needs local space, including the AI exchange corpus.

The capture delegates managed-unit stop and restart operations to a separate
transient systemd recovery service. Before stopping anything, that service records
a lease for the units that were active; it acknowledges the stop before the final
local copy begins. It runs outside the backup job's cgroup and restarts units in
reverse order if the capture or entire backup job dies, including SIGKILL, or
reaches the interruption deadline. Normal cleanup requests restart immediately
after local capture and waits for acknowledgement before removing the lease.
The recovery service retries unsuccessful starts and resumes a saved lease if
it restarts. An unfinished lease blocks another capture of the same units, and
each lease has a single recovery owner. Timed-out service commands terminate
their whole process group before recovery so no delayed stop can follow restart.

SQLite uses the native backup API, excludes copied WAL/SHM companions, and
checks the result. Managed writers such as T3 Code, CPA Manager Plus and Grafana
pause for the final database/file capture after live preseed; revision-named
no-mistakes user daemons are discovered dynamically. T3, Hermes and no-mistakes
also pause independently launched processes holding writable files in their
selected state directories. This includes the T3 desktop's separate backend,
which shares the web service's database and attachments. The desktop window
stays open while its backend pauses.

The writer pause uses Linux process descriptors to preserve process identity.
An independent transient systemd watchdog is armed before suspension and resumes
the writers if the backup exits or reaches its interruption deadline. Normal
cleanup resumes them before restarting managed services and uploading. A writer
that cannot be safely paused, or a newly appearing writer, fails the capture.
An already stopped process remains stopped. Run manual captures from a terminal
outside the backed-up application so its backend is not an ancestor of the
backup command. This process discovery covers open writable files; a process
that opens and closes files between writes can evade discovery. Hermes records
that limitation in its manifest; verify its associated files in rehearsal and
close intermittent writers when a transaction across the whole folder is needed.

PostgreSQL captures every connectable database, roles and tablespaces, with
server version and extension inventories. Forgejo's native
PostgreSQL dump and repository/LFS files are captured while Forgejo is paused.
Forgejo-dependent runners are paused and restarted with Forgejo, preserving their
initial availability. PostgreSQL remains online; databases are independent
consistent captures rather than a simultaneous cluster-wide transaction. Executor uses a clean stop and
final file copy to preserve its libSQL data and keys. Soft Serve, Tuwunel,
Syncthing, the registry, and request-exchange files use bounded stopped captures.
Node-RED pauses both its service and, when configured, its git-sync service so
both writers are stopped during the final file copy.
VictoriaMetrics uses its native snapshot and `vmbackup` filesystem format.

Home snapshots include `/home/lotus` directly, with live application state paths
replaced by prepared consistent copies. Both scopes include these selected home
application captures. Restic snapshot paths are:

- `/home/lotus/...` for ordinary home files.
- `/var/lib/machine-backups/staging/SCOPE/tree/...` for captured files, with the
  original absolute path below `tree` (for example `tree/home/lotus/.t3/userdata`).
- `.../databases/postgresql/globals.sql` and indexed `database-000.dump` archives.
  The manifest maps each archive to its database name, owner, locale and extensions.
- `.../databases/victoriametrics/` for `vmbackup` data.
- `.../recovery/recovery-inputs/input-cache/`, `archive.json`, and `closure.json`
  for locked flake inputs. The configuration and encrypted secrets are in `tree`.
- `.../capture-manifest.json` for source/resolved paths, ownership, modes, versions,
  database mappings, and capture times.

Selected root symlinks into `/var/lib/private` are materialized; symlinks inside
captured trees remain symlinks. Captures preserve numeric ownership, modes,
symlinks, ACLs and xattrs. Restore paths from the manifest; do not copy staging
prefixes into their production locations by accident. Runtime coverage checks
report unclassified service state and container mounts. DHCP leases, synchronized-clock state and
declaratively configured systemd linger are classified as regenerable; they
are not a blanket exclusion of application state. PostgreSQL parent directories
are inspected for uncovered children so an additional cluster cannot disappear
behind a classification of the parent directory. The notebook runtime
inventory still needs reconciliation during rollout.

## Restore a sample without touching production

Choose an empty target outside all source paths. The wrapper restores only a
complete snapshot for the requested host/scope, verifies its restic content,
and checks captured database formats and metadata where applicable:

```bash
sudo machine-backup restore-test --host loem --scope home --target /var/tmp/restore-loem-home
sudo machine-backup restore-test --host loem --scope services --target /var/tmp/restore-loem-services
```

For a smaller sample, supply an `--include` path visible in `restic ls`. A full
service-data rehearsal needs all archives, keys and related files, not only a
single database. `restore-test` does not start restored services or prove their
application behavior; run each service in an isolated environment using compatible
versions, with production networking and identities disabled. Record elapsed time,
application checks and coverage gaps. Repeat quarterly.

## Reinstall and recover a machine

1. Retrieve the external recovery material. If repository data was deleted,
   use the Box dashboard to roll back to a clean retained provider snapshot or
   recover it into a writable location. Verify the repository before using it.
   Hidden snapshots require the independent administrative recovery path.
2. From a recovery system with restic and SSH, configure the pinned connection
   and password/private-key files in a private runtime directory. Select a
   `machine-backup,complete` snapshot for the correct host and scope. Restore into
   an isolated directory with `restic restore SNAPSHOT --verify --target TARGET`.
   The installed `machine-backup restic -- ...` wrapper is usable on a surviving
   enrolled host and already supplies the dedicated connection and password.
3. Recover the selected flake and input cache before depending on loem's Forgejo.
   Set `capture_root` below to the restored service staging root. Copy its locked
   source closure into the recovery machine's Nix store:

   ```bash
   capture_root=/var/tmp/restore-loem-services/var/lib/machine-backups/staging/services
   recovery_root="$capture_root/recovery/recovery-inputs"
   jq -r '.[]' "$recovery_root/closure.json" > /var/tmp/backup-source-paths
   xargs -r nix copy --no-check-sigs --from "file://$recovery_root/input-cache" < /var/tmp/backup-source-paths
   flake_source=$(jq -r '.path' "$recovery_root/archive.json")
   nix eval --offline --raw "$flake_source#nixosConfigurations.loem.config.networking.hostName"
   nixos-rebuild build --flake "$flake_source#loem"
   ```

   The offline evaluation verifies that the recovered locked sources can evaluate
   the selected machine configuration. The subsequent build uses normal network
   access for public substituters and upstream package downloads. The local cache
   is authenticated by the encrypted, verified backup and contains source inputs,
   not the package/build closure or the entire original Nix store. A fully offline
   rebuild would also need those package and build artifacts preserved separately.
   Recover the mutable configuration checkout and encrypted secrets from `tree`
   if editing/rekeying for replacement hardware. Record new host public keys and
   rekey when changing identities; preserve `/etc/ssh` before activation when
   retaining the old agenix host identity. Restore SSH host private/public keys
   selectively; let the rebuilt configuration regenerate SSH configuration
   symlinks instead of retaining links into the old Nix store. Reinstall NixOS with the recovered
   machine configuration and reviewed hardware/disk settings.
4. Keep applications stopped while restoring their state. First restore ordinary
   home files, then overlay prepared home application captures from `tree/home/lotus`.
   Overlay captured non-database service files to their manifest source paths,
   preserving numeric ownership and metadata (for example `rsync -aHAX --numeric-ids`).
   Recreate declared private `StateDirectory` layouts and restore materialized
   data into their resolved targets rather than replacing systemd's symlinks.
   Restore generated keys and encrypted-secret access before starting services.
5. Restore PostgreSQL using the recorded major version and extensions. Review
   roles, tablespace locations, database names and locales before importing:

   ```bash
   sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -f globals.sql
   sudo -u postgres pg_restore --exit-on-error --create -d postgres database-000.dump
   ```

   Repeat for every application database listed in the manifest. For captured
   `postgres` and `template1`, which already exist in a freshly initialized cluster,
   use `pg_restore --exit-on-error --clean --if-exists -d DATABASE DUMP` without
   `--create`. These example paths must be
   made readable by the importing account. Import globals into a clean cluster
   initialized with a distinct recovery administrator, or review/remove only
   conflicting role declarations already created by NixOS before importing.
   Existing `postgres`/`template1` databases need deliberate handling; do not
   silently ignore restore errors. A rehearsal proves the exact import sequence
   for the captured inventory. Do not copy a live raw PostgreSQL directory.
6. SQLite captures are standalone database files; restore associated keys and
   application files from the same capture and omit old WAL/SHM files. Soft Serve,
   Tuwunel and Executor restore their complete prepared file trees while stopped.
   Restore VictoriaMetrics into an empty compatible storage directory with
   `vmrestore -src=fs://CAPTURE/databases/victoriametrics -storageDataPath=STATE`.
   Restore Grafana's encryption key alongside its database, Node-RED credential
   secret alongside its state, Syncthing/Tailscale identities, runner registration
   and relevant certificate/CA material through the configuration's secret workflow.
7. Start restored services and verify application behavior and identities. Check
   the next off-machine complete backup and monitor output. Measure recovery time.
   During rehearsals, keep restored services isolated from production networks.

## Implementation and readiness checks

- Complete the notebook runtime inventory and reconcile both coverage manifests,
  including mounts, symlink targets, all PostgreSQL databases, Docker volumes,
  generated keys, and mutable machine configuration. Flag inventory drift.
- Verify unattended Storage Box access for the actual system jobs on both hosts,
  independently retrievable recovery credentials, and the provider's daily
  ten-snapshot policy. Snapshot invisibility alone cannot verify that policy.
- Demonstrate consistent capture and reliable service restart within the
  one-minute interruption budget, including failure/timeout paths and forced
  backup-job termination. Benchmark
  first-run staging separately from recurring captures.
- Verify `.direnv` exclusion at arbitrary depth and preservation of all AI
  exchange families, even under `logs` and with `.log` extensions. The diagnostic
  exclusions must not match request exchanges.
- Verify shared-repository host/scope separation, cross-host deduplication, and
  retention dry runs. Partial snapshots must not replace complete snapshots in
  the health indicator or the retained recovery history.
- Exercise retry/locking, missed-run catch-up, failed/partial capture reporting,
  mutual overdue detection, recovery notifications, and storage thresholds.
- Build both NixOS configurations without applying them and run the appropriate
  module/script checks. Follow repository validation instructions; the user
  applies configurations separately.
- Restore representative home files and each service's data in isolation, verify
  database/key compatibility, and demonstrate recovery bootstrap without loem's
  Forgejo. Measure actual storage growth and recovery time.

Validation on 2026-10-10 passed the evaluated module and actual-profile coverage
checks, 39 capture fixtures, and 19 runner fixtures in the Nix sandbox. The
managed-service fixtures cover entire-job SIGKILL, guardian restart, outstanding
recovery leases, duplicate launch requests, delayed stop clients and coordinated
Node-RED writers. Runner regressions cover stale capacity measurement failures
and restore health recovery. The remaining runner fixture checks
ACLs and xattrs; the sandbox filesystem lacks ACL support, so that fixture passed
separately on the host filesystem. Both NixOS configurations and standalone Home
Manager built successfully. A synthetic Storage Box upload and verified restore
passed, and its test snapshot was removed. Read-only loem inventory found 17
state paths with no uncovered paths or inspection errors. No configuration was
applied and no production service capture was run.

Production service timings, notebook inventory, provider snapshot
schedule, vault export, and application-level restore rehearsals are rollout
evidence, and remain required before calling the setup ready. After the first
month, review capacity, compression/deduplication and growth against the provisional
one-year retention policy. Both hosts being unavailable can silence their mutual
monitoring; this rollout has no third independent heartbeat monitor.
