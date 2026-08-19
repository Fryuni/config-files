# Forgejo Actions runner

The loem runners are configured through the first-party nixpkgs
`services.forgejo-runner` NixOS module. Forgejo Runner v12+ needs both values
copied from the Forgejo runner UI:

- the runner UUID, committed in `servers/loem/forgejo.nix`; and
- the raw runner token, decrypted from the age secret source at
  `secrets/loem/codeberg-forgejo-actions-runner-token`.

The decrypted token file is passed to systemd as a credential and must contain
only the raw token bytes:

```text
<raw-runner-token>
```

Each instance declares `secrets.server.connections.<name>.token_url` pointing at
its agenix token path. The module loads it as a systemd `LoadCredential` named
`server__connections__<name>__token_url` and writes
`token_url: file:$CREDENTIALS_DIRECTORY/server__connections__<name>__token_url`
into the generated runner YAML. Runner units run as per-unit `DynamicUser`
services (`forgejo-runner-self`, `forgejo-runner-codeberg`,
`forgejo-runner-gitgay`) with state under `/var/lib/forgejo-runner/<name>`; the
old `/var/lib/forgejo-runner-<name>` directories from the previous custom module
are orphaned after the migration and can be removed manually.

Docker builds run against the host Docker daemon via the mounted Docker socket.
Only run trusted workflows on this runner because those jobs can control the host
Docker daemon.

The local Forgejo runner also exposes `nix:host`. Workflows select it with
`runs-on: nix` and execute directly as the unprivileged `DynamicUser` of the
`forgejo-runner-self` unit. The runner PATH includes the host Nix client, so
flake builds use the host Nix daemon and its existing `/nix/store` instead of
creating a second store in a container. The runner is not a Nix trusted user.

Only grant the `nix` target to trusted repositories: host jobs run arbitrary
commands outside a container, can write their runner state directory, and can
ask the Nix daemon to build or copy store paths. Cache credentials must still be
provided by each workflow through Forgejo Actions secrets.

Each runner process has capacity 5, allowing five matching jobs from the same
Forgejo instance to run concurrently. The three runner processes are independent.

For the instance-wide runner, open the Codeberg/Forgejo runner settings page and
choose **Create new runner**. Copy both the UUID and token from Forgejo; this is
not a user access token.

Scope-specific runners use the same **Actions -> Runners -> Create new runner**
flow from a narrower settings page:

- Organization: `/org/{org}/settings/actions/runners`
- User: `/user/settings/actions/runners`
- Repository: `/{owner}/{repository}/settings/actions/runners`

When rotating credentials, update the UUID in `servers/loem/forgejo.nix` and
replace the raw token encrypted in the age secret. Both values must come from
the same Forgejo runner UI entry.

To rotate the token, encrypt the new raw token for the recipients in
`secrets.nix`:

```sh
printf '<raw-runner-token>\n' \
  | nix run nixpkgs#rage -- \
      -r 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDWC3o9JGhJTmLg8q/NBVbaN1yXR9MVHln2xHO6WDlHp' \
      -r 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw' \
      -r 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN4weIfIxf3RMmhSII89HEGPqToqNKlwdYFW79CaBqCQ' \
      -r 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPZwBNlYpC3tigLKDxyU6+6jik0J63IIqT6DiFk7Dekc' \
      -o secrets/loem/codeberg-forgejo-actions-runner-token
```

Then run `just rekey` to refresh the repository's agenix-rekey outputs, and stage:

```sh
git add secrets/loem/codeberg-forgejo-actions-runner-token secrets/rekeyed/loem
```
