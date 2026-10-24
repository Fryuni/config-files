# Keep the corpus archive in the shared backup repository

AI exchanges must be kept permanently, but `loem` cannot keep accumulating them,
and ordinary restore points expire after a year once their source files are gone.
Settled exchanges therefore move into retention-exempt restore points in the
shared restic repository, tagged `permanent-archive` instead of `machine-backup`,
and are deleted locally only after the new restore point verifiably records them.
Hourly service backups have already uploaded their content, so the archive adds
almost no storage and reuses the repository's encryption, integrity checks,
credentials and monitoring.

## Considered Options

- **Plain files in another Storage Box directory**: readable without restic, but
  stores full exchanges unencrypted on the provider (or needs a new key), uploads
  the corpus again, and keeps a second copy until ordinary backups expire.
- **A separate restic repository**: independent of backup retention, but loses
  deduplication against existing service backups for no stronger access boundary,
  since the same backup identity can delete either.
- **CLIProxyAPI's request-log bucket upload**: deletes after upload natively, but
  needs an S3-compatible target the Storage Box lacks, and provides no compression
  or encryption.

## Consequences

The corpus is readable only through restic with the repository password, and its
lifetime is tied to the repository: migrating or re-initializing the repository
must copy the archive restore points too. Retention must keep selecting restore
points by the `machine-backup` tag; a policy that selects by host alone would
delete the corpus.
