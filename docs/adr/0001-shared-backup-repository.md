# Share one backup repository across machines

`loem` and `note` will share one restic repository on the Hetzner Storage Box so
identical content can deduplicate across both machines as well as across time.
Each machine retains independent restore points, identified by host and backup
scope; a backup does not replace the other machine's files or history.
This trades separate repository access boundaries and independent maintenance
for shared storage savings, with retention applied independently to each host
and backup scope.

Both machines can decrypt the repository's contents and have storage write
access. Provider snapshots supply the agreed recovery layer for repository
deletion; they do not create access isolation between the machines.

[Restic documents shared repositories and cross-host deduplication](https://restic.readthedocs.io/en/stable/040_backup.html).
