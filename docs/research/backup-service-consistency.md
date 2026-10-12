# Service backup consistency and interruption

Researched on 2026-10-12 against this checkout, official documentation, and the
exact CLIProxyAPI and T3 Code source revisions selected by the locked
`llm-agents` input. This is a research note and design assessment; it changes no
capture implementation. It does not establish production recovery readiness.

After this research, the user chose uninterrupted CLIProxyAPI and T3 Code
sessions over coordinated capture of their associated files. Their registrations
now keep all service processes online: T3 retains consistent SQLite exports,
while associated files and CLIProxyAPI state/request exchanges are read live.
Incomplete recent files and credential-rotation races are accepted. This decision
supersedes the pause recommendations for those two services below; implementation
descriptions below record the configuration inspected during research.
See the [adopted backup policy](../backups.md#recovery-decisions).

## Answer

**Restic does not require stopping every service. It requires readable source
files; the application determines how to obtain recoverable state.** An online
database export, a native application snapshot, or appropriately coordinated
filesystem snapshot can supply stable input without keeping the application
offline during transfer. Restic's recorded restore point should not be mistaken
for an atomic snapshot of a changing Linux filesystem: its documented automatic
filesystem snapshot option uses Windows VSS. The consistency implication for
our direct Linux file reads is an assessment of that capture method.
[Restic backup documentation](https://restic.readthedocs.io/en/stable/040_backup.html).

For this setup, the user's intuition about reducing downtime is sound, but
**neither CLIProxyAPI nor T3 Code is safely classified as stateless**. CLIProxyAPI
rewrites credentials and creates exchange files in place. T3 Code has SQLite
plus attachments, secrets, settings, and terminal history. Forgejo has the
clearest need for coordinated capture because its database and repository/file
storage must agree. These findings follow from the service-specific sources
below, rather than a Restic rule.

## What our implementation actually does

The capture engine registers stopped units and suspended writers in one
`Selection.stack`, prepares each capture, then calls `consume(selection)` before
leaving that stack. The runner's consumer performs the Restic backup. Pauses
therefore accumulate and last through remaining preparation and the entire
scan/upload; services are not independently resumed immediately after their own
capture. This implements the previously documented choice to avoid duplicating
large file trees locally. [Capture engine](../../common/backups/capture.py),
[runner](../../common/backups/runner.py),
[existing capture policy](../backups.md#capture-layout-and-consistency).

The policy is already selective: PostgreSQL remains running while logical dumps
are generated, VictoriaMetrics uses its native snapshot API without a stop unit,
and Tailscale, Caddy, Tailnet certificates, inbox files, and NetworkManager
connections have no declared service stop. Forgejo and its dependent runners
are stopped around the coordinated Forgejo database/file capture.
[PostgreSQL registration](../../servers/loem/postgresql.nix),
[metrics registrations](../../servers/loem/metrics/default.nix),
[Forgejo coordination](../../servers/loem/forgejo.nix),
[identity registration](../../nixos/modules/networking/tailscale.nix),
[certificate and Caddy registrations](../../nixos/modules/networking/tailnet-access.nix),
[inbox registration](../../nixos/modules/networking/tailscale-file-inbox.nix),
[NetworkManager registration](../../nixos/modules/networking/default.nix).

SQLite captures already use `sqlite3.Connection.backup`, check the result, and
exclude the original database plus WAL/SHM/journal companions from direct Restic
reads. Other files in those directories are still read directly. The existing
stop/pause protects associated mutable files and cross-file relationships; it
is not required merely because the database is SQLite.
[SQLite capture code](../../common/backups/capture.py),
[Python backup API](https://docs.python.org/3/library/sqlite3.html#sqlite3.Connection.backup).

The existing inventory records ext4 roots with no source filesystem snapshot
facility. Storage Box snapshots preserve the remote backup repository; they
cannot repair an inconsistent source capture.
[Existing inventory and recovery decisions](../backups.md#verified-findings),
[repository terminology](../../CONTEXT.md).

## Which consistency is needed?

- **A database must be internally consistent.** Copying SQLite database bytes
  while a transaction is changing them can produce corruption; copying its
  companions at other times does not fix that. SQLite provides an online backup
  API specifically for a consistent destination while clients remain active.
  [SQLite corruption guidance](https://sqlite.org/howtocorrupt.html#_backup_or_restore_while_a_transaction_is_active),
  [online backup API](https://sqlite.org/backup.html).
- **Files referenced by a database must survive the same capture.** A valid
  database export can still refer to an attachment or repository state missing
  from files read later. Conversely, independent files do not all need one common
  instant. This is an application-level requirement, illustrated explicitly by
  Forgejo's guidance below.
  [Forgejo backup guidance](https://forgejo.org/docs/latest/admin/upgrade/#backup).
- **Acceptable incompleteness must be explicit.** Recent writes after a capture
  boundary are normal backup data loss. An unfinished AI exchange is different
  from silently dropping the corpus, and a partial terminal history is different
  from corrupting the conversation database. Treating those as acceptable would
  be a recovery-policy decision, not a guarantee provided by Restic.
  [Complete restore point and AI exchange corpus definitions](../../CONTEXT.md),
  [current approved exclusions](../backups.md#data-classification-and-exclusions).

An online SQLite backup gives one consistent database, not a coordinated cut
across several databases and external files. Heavy concurrent writes can also
restart an incremental backup repeatedly. Both are reasons to design the
capture boundary carefully, rather than assume that every online export is
automatically a full application backup.
[SQLite backup behavior](https://sqlite.org/backup.html).

## T3 Code

The locked package source is Fryuni's fork at
`2e2b14edf627fe557d5c7420d3117e09ea814463`, version
`0.0.45-fork.20261009.16-unstable-2026-10-09`; it was identified from the cached
`llm-agents` package definition and inspected at that exact revision.
The service captures `/home/lotus/.t3/userdata` as SQLite, stops `t3code.service`,
and suspends other detected writers, including independently launched backends.
[Locked input](../../flake.lock),
[service registration](../../nixos/modules/t3code.nix),
[pinned application source](https://github.com/Fryuni/t3code/tree/2e2b14edf627fe557d5c7420d3117e09ea814463).

The application configures WAL mode for `statev2.sqlite`. The same `userdata`
directory contains attachments, browser artifacts, settings, themes, secrets,
runtime metadata, provider logs, and terminal history. Worktrees live outside
that directory under `.t3/worktrees`; they are covered by the general home
selection rather than this dedicated directory capture.
[SQLite configuration](https://github.com/Fryuni/t3code/blob/2e2b14edf627fe557d5c7420d3117e09ea814463/apps/server/src/persistence/Sqlite.ts),
[derived paths](https://github.com/Fryuni/t3code/blob/2e2b14edf627fe557d5c7420d3117e09ea814463/apps/server/src/config.ts),
[home backup selection](../../nixos/modules/machine-backups.nix).

There is real associated file mutation. Uploads use a `.part` file and rename
when complete, but claiming an upload copies it to a thread-specific file before
message persistence. Cleanup can remove claimed attachments; terminal history
is rewritten with `writeFileString`. The attachment-claim code also explicitly
allows an agent to edit an already delivered attachment in place, so completed
attachments cannot universally be treated as immutable. Settings and runtime metadata do use an
atomic-write helper, which protects those individual publications but does not
coordinate them with the database export.
[Upload publication](https://github.com/Fryuni/t3code/blob/2e2b14edf627fe557d5c7420d3117e09ea814463/apps/server/src/assets/AttachmentUpload.ts),
[attachment claims](https://github.com/Fryuni/t3code/blob/2e2b14edf627fe557d5c7420d3117e09ea814463/apps/server/src/orchestration-v2/AttachmentClaims.ts),
[cleanup](https://github.com/Fryuni/t3code/blob/2e2b14edf627fe557d5c7420d3117e09ea814463/apps/server/src/orchestration-v2/ResourceCleanupService.ts),
[terminal persistence](https://github.com/Fryuni/t3code/blob/2e2b14edf627fe557d5c7420d3117e09ea814463/apps/server/src/terminal/Manager.ts),
[settings](https://github.com/Fryuni/t3code/blob/2e2b14edf627fe557d5c7420d3117e09ea814463/apps/server/src/serverSettings.ts),
[runtime metadata](https://github.com/Fryuni/t3code/blob/2e2b14edf627fe557d5c7420d3117e09ea814463/apps/server/src/serverRuntimeState.ts).

**Assessment:** T3 Code's database can be backed up online using the mechanism
we already have. A complete `userdata` backup still needs an explicit strategy
for related files: briefly stop/cooperate with writers, capture the database and
required files into stable local storage, resume, then upload; or add a supported
application export/retention protocol. Removing the stop flags while continuing
to read the whole directory directly would weaken the intended recovery
consistency. The important opportunity is removing upload time from the interruption,
not pretending there are no stateful files.

## CLIProxyAPI

The locked package selects Fryuni's fork at
`6b763383c43ac26af5890e3b1f32717598812b8d`, version
`0-unstable-2026-10-04`. Its registration directly reads all of
`/var/lib/cli-proxy-api`, excluding only approved diagnostic `main.log` and
`main-*.log`. The existing inventory records about 38 GiB, primarily valuable
AI exchanges. The configured paths include mutable auth files and `config.yaml`.
[Locked input](../../flake.lock),
[service registration](../../servers/loem/cli-proxy-api.nix),
[corpus classification](../backups.md#data-classification-and-exclusions).

The credential file store has an existing-file path using `O_TRUNC` followed by
`Write`, and a new-file path using `os.WriteFile`. Configuration saving also
uses `os.WriteFile`. These are direct mutable-file writes, not universally
temp-file-and-rename publication. An internal mutex does not coordinate an
external Restic reader. Some provider-specific writers differ, so no universal
claim about every credential format is made.
[Token file store](https://github.com/Fryuni/CLIProxyAPI/blob/6b763383c43ac26af5890e3b1f32717598812b8d/sdk/auth/filestore.go),
[configuration writer](https://github.com/Fryuni/CLIProxyAPI/blob/6b763383c43ac26af5890e3b1f32717598812b8d/internal/config/config_yaml.go).

Exchange filenames are unique and opened with `O_EXCL`, but the final filename
is visible before the writer finishes its content. Streaming requests stage
body fragments in temporary files; closing the stream creates and writes the
final exchange file. Thus unique creation is not an atomic completed-file
publication, and raw live selection can observe unfinished exchanges or
temporary bodies.
[Exchange writer](https://github.com/Fryuni/CLIProxyAPI/blob/6b763383c43ac26af5890e3b1f32717598812b8d/internal/logging/request_logger_writer.go),
[streaming finalization](https://github.com/Fryuni/CLIProxyAPI/blob/6b763383c43ac26af5890e3b1f32717598812b8d/internal/logging/request_logger_streaming.go).

**Assessment:** CLIProxyAPI should be a good candidate for mostly online
capture, because completed exchange files can be treated independently of
small mutable credentials/configuration. A future design could publish
completed exchanges atomically or identify them through a completion manifest,
capture that fixed corpus selection online, and briefly coordinate/copy the
small mutable state. Deletion/cleanup must respect that selection until upload
finishes. A modification-time cutoff alone is only a heuristic, not proof of
completion. Do not silently exclude the corpus or all `.tmp` files: transient
exchange bodies need explicit classification and a decision about in-flight
requests. With today's raw directory capture, simply removing the service stop
would introduce live-write races into the intended consistent capture.

## Forgejo and PostgreSQL

Forgejo's official guidance calls for a synchronized point-in-time capture of
all storage. It explicitly permits an online VM snapshot when everything is
captured together and recommends shutdown for unsynchronized storage. It also
warns about the SQL export in `forgejo dump` and advises a separate native SQL
dump. That supports our coordinated Forgejo file selection plus PostgreSQL dump,
without requiring PostgreSQL itself to stop.
[Forgejo backup guidance](https://forgejo.org/docs/latest/admin/upgrade/#backup),
[our coordinated capture](../../servers/loem/forgejo.nix).

`pg_dump` provides a consistent export while readers and writers continue;
cluster-wide roles and other globals require `pg_dumpall`. Independent database
dumps do not imply one common transaction boundary for every application in the
cluster. The special Forgejo pause protects its file/database relationship,
not ordinary PostgreSQL dump correctness.
[PostgreSQL pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html),
[pg_dumpall](https://www.postgresql.org/docs/current/app-pg-dumpall.html),
[our PostgreSQL capture](../../common/backups/capture.py).

**Assessment:** Keep Forgejo coordinated with its runners for the current
direct-file pipeline. It could resume before remote transfer if its file state
and database dump were first retained as a stable coordinated local capture.
A filesystem/storage redesign can also reduce interruption, but capturing
different volumes independently is not automatically synchronized.

## Other enrolled state

The following are recommendations, not a claim that every pinned application
has been exhaustively audited. Local registrations establish current behavior;
where an upstream online facility is named, its availability in the deployed
version still needs checking.

| Capture | Current method | Assessment |
| --- | --- | --- |
| PostgreSQL | Online native dumps and globals | Keep running; already correct at the database-export level. |
| VictoriaMetrics | Native snapshot API; no stop | Already online. Retain the native snapshot through transfer and preserve its link targets. [Official snapshot guidance](https://docs.victoriametrics.com/victoriametrics/single-server-victoriametrics/#how-to-work-with-snapshots), [registration](../../servers/loem/metrics/default.nix). |
| CPA Manager Plus | SQLite export plus direct associated files; stop | Candidate for online DB export plus stable capture of keys/config; exact cross-file writes were not audited here. [Registration](../../servers/loem/cpa-manager-plus.nix). |
| Grafana | SQLite export plus direct data/key files; stop | Native SQLite export can run online, but preserve encryption key and plugin/config consistency. Grafana's documented plain-file SQLite procedure recommends stopping. [Official backup guide](https://grafana.com/docs/grafana/latest/administration/back-up-grafana/), [registration](../../servers/loem/metrics/default.nix). |
| Hermes and no-mistakes | SQLite exports, associated files, detected-writer pauses | Same distinction as T3: online per-DB export is possible; associated file mutation and independent processes require audit before removing pauses. [Hermes](../../nix-home/modules/hermes.nix), [no-mistakes](../../nix-home/terminal/ai.nix). |
| Tuwunel | Offline direct RocksDB/media directory | Keep stop for raw copy. Upstream documents online RocksDB backup/checkpoints, but they exclude media; investigate that path with a media-retention strategy and pinned-version verification. [Official backups](https://matrix-construct.github.io/tuwunel/backups.html), [registration](../../servers/loem/matrix.nix). |
| Soft Serve | Offline direct state directory | Keep stop until database/repository relationships and a stable capture mechanism are verified. [Registration](../../servers/loem/soft-serve.nix). |
| Executor | Offline container state directory | Keep stop until database format, associated keys, and supported online capture are verified. [Registration](../../servers/loem/executor.nix). |
| Docker registry and GC | Offline direct data directory | Keep coordinated writer/GC interruption for a fully consistent raw tree, or retain a stable snapshot; an online blob/manifest strategy needs its own audit. [Registration](../../servers/loem/docker-registry.nix). |
| Forgejo runner state | Offline working directories | Coordinate with Forgejo; separately classify registration credentials, work state, and any disposable caches rather than dropping the entire capture. [Registration](../../servers/loem/forgejo.nix). |
| Syncthing current/legacy state | Offline direct directories | Config and identity have different requirements from the index database. Do not copy an arbitrary live index as if consistent; any decision to rebuild or omit it requires explicit policy and recovery rehearsal. [Official state layout](https://docs.syncthing.net/users/config.html), [registrations](../../nix-home/default.nix). |
| Node-RED and Git sync | Offline direct user directory | Keep writer coordination until flows, credentials, context storage, and Git updates have an established coherent online capture. [Registration](../../nix-home/modules/node-red.nix). |
| Tailscale/Caddy/certificates/NetworkManager/inbox/SSH identities | Direct files, no declared stop units | Already online. Rotating identities and certificate/key pairs still merit recovery verification; lack of a stop flag is not a proof of cross-file atomicity. [Networking modules](../../nixos/modules/networking), [backup module](../../nixos/modules/machine-backups.nix). |
| Home files and locked recovery inputs | Direct home reads plus staged Nix artifacts | General home files have ordinary live-file limitations; use dedicated service captures for databases. Build-input preservation is separate from service interruption. [Runner](../../common/backups/runner.py), [capture engine](../../common/backups/capture.py). |

## Recommended direction and limits

1. Make the required recovery consistency explicit per capture: database-only,
   coordinated application state, or independent completed files.
2. Keep the online mechanisms already present. For SQLite services, retain
   `Connection.backup` and solve the associated file problem separately.
3. For CLIProxyAPI, avoid tying transfer of the large completed AI exchange corpus
   to a service outage. First establish completion publication/selection and
   deletion retention, then capture small mutable state with brief coordination.
4. Where a full coordinated capture remains necessary, pause only while making
   stable local artifacts, then resume before transfer. This changes the current
   no-duplicate-file-tree policy and needs an explicit disk-space/IO tradeoff.
5. Rehearse restore under concurrent write/delete activity, checking application
   references, generated keys, and corpus completeness as well as database checks.

These are design proposals. Hard-linking a mutable file does not freeze its
bytes, and uncoordinated copying or rsync does not create an atomic boundary.
Suspending a process with `SIGSTOP` is also not an application flush or drain
protocol: it can freeze an unfinished ordinary file write. Current detected
writer coverage is best understood as a mutation-control mechanism, not proof
that every external file is at a clean application boundary.
[Current writer suspension and direct selection](../../common/backups/capture.py),
[documented writer-coverage limitation](../../nix-home/modules/hermes.nix).

No live databases, credentials, corpus payloads, production backup runs, or
restore rehearsals were accessed for this research. Package pins describe this
checkout, not independently verified installed versions on both machines. The
source-backed conclusions are strongest for Restic, SQLite, PostgreSQL, Forgejo,
CLIProxyAPI, and T3 Code; other-service rows deliberately retain conditional
recommendations until their storage behavior is verified.
