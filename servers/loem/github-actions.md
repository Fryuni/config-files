# GitHub Actions runners

`github-actions.nix` uses the first-party nixpkgs `services.github-runners`
module. Edit only `github-actions-runners.nix` to add registrations: each key is
either `owner/repository` or an organization, and its value names a credential.
Personal accounts have no account-wide runner registration. An organization
registration serves the repositories allowed by its GitHub runner group.

| Scope | Service | Credential |
| --- | --- | --- |
| `Fryuni/t3code` | `github-runner-repo-fryuni-t3code` | `fryuni` |
| `fryuni-testorg` | `github-runner-org-fryuni-testorg` | `fryuni-testorg` |

Adding another personal repository can reuse the `fryuni` credential if that
token also grants access to the new repository:

```nix
"Fryuni/another-repository" = "fryuni";
```

Each entry gets a separate service, registration, and disk-backed workspace
under `/var/lib/github-runner-work/<runner-id>`. Registration state lives under
`/var/lib/github-runner/<runner-id>`. Each runs as its own static system user
`gh-runner-<runner-id>`, so the workspace keeps one real path and a stable owner
rather than the `/var/lib/private` indirection a dynamic user would impose. The
upstream module cleans the workspace whenever the service starts, not between
jobs. Runner names in GitHub are prefixed with `loem-`. Changes to registration
settings reuse that name.
Removing a map entry stops managing its service; remove its stale registration
in GitHub as well.

Each registration handles one job at a time. The initial two registrations can
therefore run two jobs concurrently, independently of the Forgejo runners. Every
additional map entry adds another listener and potential concurrent job; this
configuration does not impose a global concurrency limit. Host Nix builds retain
loem's existing daemon limits (`max-jobs = 2`, `cores = 3`).

## Workflow selection

```yaml
jobs:
  build:
    runs-on: [self-hosted, nix, loem]
    steps:
      - uses: actions/checkout@v5
      - run: nix build
```

The default `self-hosted`, `Linux`, and `X64` labels are retained, with `nix`,
`nixos`, `docker`, and `loem` added. Jobs run on NixOS using the host Nix daemon
and store. The runner uses the packaged Node 24 runtime. These runners do not advertise
Ubuntu labels: workflows needing Ubuntu should specify a job `container:`.
Docker CLI commands, container jobs, and Docker actions use the host daemon.
The workspace has the same path for the runner and Docker bind mounts.

Only assign trusted workflows to these runners: Docker access grants control
over the host. Runner users are not added to Nix's trusted users. Organization
runner group access is managed in GitHub; public repository access is disabled
by default and must be enabled there if needed.

## Credentials and first deployment

Create two fine-grained PATs, each with its corresponding resource owner:

- `Fryuni`: select `t3code` and grant repository **Administration: read and write**.
- `fryuni-testorg`: grant organization **Self-hosted runners: read and write**.

These permissions are documented by the GitHub
[repository registration API](https://docs.github.com/en/rest/actions/self-hosted-runners#create-a-registration-token-for-a-repository)
and [organization registration API](https://docs.github.com/en/rest/actions/self-hosted-runners#create-a-registration-token-for-an-organization).
The NixOS module exchanges a PAT for a registration token when registration is
needed. Do not use the one-hour token from the "New self-hosted runner" page;
this configuration explicitly expects access tokens. Renew PATs before expiry.

The preferred credential source is agenix. From the repository root, create:

```sh
FILE=secrets/loem/github-actions-fryuni-token agenix -e secrets/loem/github-actions-fryuni-token
FILE=secrets/loem/github-actions-fryuni-testorg-token agenix -e secrets/loem/github-actions-fryuni-testorg-token
git add secrets/loem/github-actions-fryuni-token secrets/loem/github-actions-fryuni-testorg-token
just rekey
git add secrets/rekeyed/loem
```

Each encrypted file must contain only its raw PAT, without quotes or a trailing
newline. `FILE` allows `secrets.nix` to assign recipients to a new file. Once the
encrypted source is present in the flake, the module declares its root-owned,
mode `0400` agenix secret automatically. Rekey before building or deploying.
Rotate credentials by editing and rekeying those same files.

Until encrypted sources are supplied, the module instead expects root-owned,
mode `0400` files on loem at `/var/lib/github-runner-tokens/fryuni` and
`/var/lib/github-runner-tokens/fryuni-testorg`. The parent directory is created
with mode `0700`; token files are never generated. This bootstrap path keeps the
configuration buildable before secrets exist, but services cannot register until
credentials are provisioned. No credentials are included in this change.
After migrating to agenix, remove any unused bootstrap token files from loem.
The upstream module reads credentials during privileged setup and hides the
original token and its retained copy from the job service.

Build loem without activating it:

```sh
direnv exec . nix build .#nixosConfigurations.loem.config.system.build.toplevel --no-link
```

After applying the configuration separately, check both services:

```sh
systemctl status github-runner-repo-fryuni-t3code github-runner-org-fryuni-testorg
journalctl -u github-runner-repo-fryuni-t3code -u github-runner-org-fryuni-testorg
```

Confirm they appear online in the corresponding repository and organization
**Settings > Actions > Runners** pages, then run a workflow using the labels above.
