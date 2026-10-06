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

- [Shared Nix cache](nix-store-cache.md#credential-maintenance) covers the cache write
  token and daemon credentials.
- [Forgejo Actions runners](../servers/loem/forgejo-actions.md) covers runner UUIDs and
  token rotation.
- [GitHub Actions runners](../servers/loem/github-actions.md#credentials-and-first-deployment)
  covers agenix credentials and bootstrap token files.
