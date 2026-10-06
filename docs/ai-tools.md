# AI tools

[Project overview](../README.md) · [Architecture](architecture.md)

The shared terminal AI configuration lives in `nix-home/terminal/ai.nix` and is used by
the notebook and interactive-server Home Manager layers. The tools come from the pinned
`llm-agents` flake input, with local wrappers and configuration where needed.

## T3 Code

The notebook's Home Manager UI module installs `llm-agents.t3code-desktop` from the same
pinned `llm-agents.nix` flake as the CLI and backend.

`note` and `loem` import `nixos/modules/t3code.nix`. It runs `llm-agents.t3code`'s
`t3 serve` as `lotus`, restarting on exit. On hosts with X enabled (`note`), it is a
systemd user service attached to `graphical-session.target`: it starts with the desktop,
inherits its display and authentication environment, and stops at graphical logout. T3
and its tools therefore have local desktop access even when the client connects
remotely. A new graphical login starts it with fresh credentials. On headless hosts
(`loem`), it remains a boot-enabled system service without requiring a login session.
Both forms use `/home/lotus` for their working directory and home, retaining T3's
default per-user state and provider credentials; PATH includes the user's Nix profiles
and system tools.

The backend binds only to `127.0.0.1:3773`. The existing tailnet DNS, certificates, and
Caddy proxy expose the `t3` alias at `https://t3.note.lferraz.dev` and
`https://t3.loem.lferraz.dev`; no public backend port or separate Tailscale Serve
configuration is added. T3's own pairing/authentication remains enabled. Inspect startup
and pairing details with `journalctl --user -u t3code.service` on `note`, or
`journalctl -u t3code.service` on `loem`. After applying the configuration, the user
service starts on the next graphical login, or with
`systemctl --user start t3code.service` from the active desktop.

## Claude Code

The shared terminal AI module installs `llm-agents.claude-code` with a wrapper that
routes requests to `https://llm.loem.lferraz.dev`, including when launched by T3. The
base URL omits `/v1` because the Anthropic client adds it. Loem currently requires no
client API key; the wrapper supplies a non-secret placeholder auth token to satisfy
Claude Code's client-side authentication check and clears `ANTHROPIC_API_KEY`.
Nonessential Claude Code traffic is disabled. The wrapper leaves Claude's user settings
and session files writable.

## Herdr

The shared terminal AI module imports `nix-home/terminal/herdr/` on notebook and
interactive-server Home Manager configurations. It owns Herdr's `config.toml` and
`plugins.json`; session files, logs, and plugin state remain writable and unmanaged.
Change settings and the installed plugin set in the flake rather than through Herdr's
settings or plugin-management commands.

`nix-home/terminal/herdr/plugins/` defines store-backed plugin packages. The current
Treehouse integration comes from the locked `herdr-treehouse` flake input; its upstream
flake provides only development shells, so the local package definition installs its
manifest and scripts with store paths for Python, Git, Gum, and Treehouse. Add
repository-local custom plugins in this directory; Git-backed plugins should use pinned
flake inputs (`flake = false` for repositories without a flake).

For the first activation on a machine with a manual setup, back up
`~/.config/herdr/config.toml` and `~/.config/herdr/plugins.json` before replacing them
with Home Manager's links, or use Home Manager's backup option. Existing files are not
force-overwritten. The adopted configuration currently enables only
`local.herdr-treehouse`; historical plugin state is not an installation source. Reload
or restart Herdr after applying the generation.

For shell access to the local display, see
[Notebook desktop](desktop.md#desktop-access-from-shells).
