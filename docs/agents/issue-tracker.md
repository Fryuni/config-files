# Issue tracker: Forgejo

Issues and specs for this repo live on the self-hosted Forgejo instance at
`git.fryuni.dev` (repo `Fryuni/nix-files`). Use the `fj` CLI for all operations.

## Conventions

- **Create an issue**: `fj issue create --body "..."` (use `--body-file` for
  multi-line bodies)
- **Read an issue**: `fj issue view <id> comments` (comments) or
  `fj issue view <id>` (summary); labels via `fj issue edit <id> labels` review
  or `fj repo labels view`
- **List issues**: `fj issue search --state open --all` (add `--labels <l>` to
  filter by label)
- **Comment**: `fj issue comment <id> --body-file <f>` (or inline body)
- **Apply / remove labels**: `fj issue edit <id> labels --add "..."` /
  `--rm "..."` (create missing labels first with `fj repo labels create <name> <hex-color>`)
- **Close**: `fj issue close <id> --with-msg "..."` (closing comment supported
  in one step, unlike glab)
- **Assign** (wayfinder claim): `fj issue assign <id> <user>`
- **Dependencies** (wayfinder blocking): `fj issue depend add <child> <blocker>` —
  Forgejo's native issue dependencies; view with `fj issue depend list <id>`

`fj` resolves the repo from the working directory (git remote), so no `-r` flag
is needed inside this clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external
PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, via
the `fj pr` equivalents (`fj pr search`, `fj pr view`, `fj pr comment`,
`fj pr edit labels --add/--rm`, `fj pr close`). External contributors are
authors who are not the repo owner (`Fryuni`).

Forgejo shares one number space across issues and PRs, so a bare `#42` may be
either: resolve with `fj issue view 42`, fall back to `fj pr view 42`.

## When a skill says "publish to the issue tracker"

Create a Forgejo issue with `fj issue create`.

## When a skill says "fetch the relevant ticket"

Run `fj issue view <id> comments`.
