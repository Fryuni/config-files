# Secrets and host identities

[Project overview](../README.md) · [Architecture](architecture.md)

Secrets are managed with age through agenix and agenix-rekey:

- `secrets.nix` defines the recipient public keys and discovers encrypted files under
  `secrets/`.
- `agenix-rekey.nix` and the flake-level `agenix-rekey` configuration wire rekeying into
  NixOS configurations that expose `config.age`.
- NixOS systems receive the agenix and agenix-rekey modules before host-specific
  modules.
- Home Manager modules may also consume agenix secrets where imported, such as the
  `lotus@note` configuration.

The `secrets/` tree contains encrypted material and host-key data. Do not treat file
names there as an application inventory; the active consumers are the NixOS and Home
Manager modules that reference individual secrets.

## Host identities and rekeying

`agenix-rekey.nix` uses each host's `/etc/ssh/ssh_host_ed25519_key` as its decryption
identity. Public host keys are recorded in `secrets/host-keys/<hostname>.pub`, and
host-specific encrypted outputs are kept in `secrets/rekeyed/<hostname>/`. Rekeying uses
the configured master identity at `/home/lotus/.ssh/id_ed25519`.

For a newly provisioned host, `just hostkey <config> <host>` records and stages its SSH
public key. Verify that the key belongs to the intended machine before using it as a
recipient. Run `just rekey` after changing encrypted sources or host keys, then stage
the updated encrypted material and affected rekeyed files before building the
configuration.

Hosts without a recorded public key use agenix-rekey's dummy recipient so an initial
configuration can build. They cannot decrypt secrets until a real host identity is
registered and the secrets are rekeyed. `gce-automation` still needs a stable hostname
and host key for this workflow.

## Service-specific credentials

- Backups have a dedicated shared SSH identity. Its encrypted private key is
  [secrets/storagebox-backup-ssh-key](../secrets/storagebox-backup-ssh-key), governed
  by the normal `secrets.nix` recipient policy; its public key is
  [common/ssh/storagebox-backup.pub](../common/ssh/storagebox-backup.pub).
  The public key is authorized on `u688316.your-storagebox.de`, and SSH
  and SFTP access on port 23 were verified with that identity alone. SFTP on port
  22 was also verified with that identity and pinned RSA host trust. Backups use
  port 22, with RFC4716 public-key enrollment; capacity monitoring retains SSH
  command access on port 23. The
  [backup module](../nixos/modules/machine-backups.nix) declares it through
  `rekeyFile` with root-only runtime permissions. Future hosts receive the same identity through agenix-rekey,
  without another Storage Box authorization change. See the
  [backup guide](backups.md) and [identity decision](adr/0002-shared-backup-access-identity.md).
  The random repository password is encrypted in `secrets/restic-backup-password`;
  both hosts receive the same password. The separate Gotify backup application
  token is encrypted in `secrets/restic-backup-gotify-token` and rekeyed to both hosts.
  Rotate the separate Gotify backup
  application token with `bash common/backups/provision-gotify.sh`, then run
  `just rekey` and stage the affected host outputs. The helper writes only
  `secrets/restic-backup-gotify-token` ciphertext. Until that source is provisioned,
  the module uses a root-only bootstrap token path at
  `/var/lib/machine-backups/credentials/gotify-token`; notifications remain queued
  without a valid token. Keep the repository password, backup SSH private key,
  agenix recovery identity, and independent Storage Box administrative access in
  the external recovery vault. Repository initialization has already succeeded
  with the dedicated identity. Rotating its password requires changing the
  restic repository key as well as the encrypted source; replacing the source
  alone does not rotate the existing repository.
- [Shared Nix cache](nix-store-cache.md#credential-maintenance) covers the cache write
  token and daemon credentials.
- [Forgejo Actions runners](../servers/loem/forgejo-actions.md) covers runner UUIDs and
  token rotation.
- [GitHub Actions runners](../servers/loem/github-actions.md#credentials-and-first-deployment)
  covers agenix credentials and bootstrap token files.
