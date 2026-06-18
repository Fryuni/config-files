# Forgejo Actions runner

The loem runner is configured through the repository-local `services.forgejo-runner`
module. Forgejo Runner v12+ needs both values copied from the Forgejo runner UI:

- the runner UUID, committed in `servers/loem/forgejo.nix`; and
- the raw runner token, decrypted from the age secret source at
  `secrets/loem/codeberg-forgejo-actions-runner-token`.

The decrypted token file is passed to systemd as a credential and must contain only
the raw token bytes:

```text
<raw-runner-token>
```

The module writes `token_url = "file:$CREDENTIALS_DIRECTORY/..."` into the generated
runner YAML.

Docker builds run against the host Docker daemon via the mounted Docker socket.
Only run trusted workflows on this runner because those jobs can control the host
Docker daemon.

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
