# AI tools

[Project overview](../README.md) · [Architecture](architecture.md)

The shared terminal AI configuration lives in `nix-home/terminal/ai.nix` and is used by
the notebook and interactive-server Home Manager layers. The tools come from the pinned
`llm-agents` flake input, with local wrappers and configuration where needed.

## T3 Code

The notebook's Home Manager UI module installs `llm-agents.t3code-desktop` from the same
pinned `llm-agents.nix` flake as the CLI and backend.

In the notebook's i3 session, `Super+T` focuses an existing T3 Code Desktop window
on any workspace, or launches the desktop app when no matching window is open.

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

## Hollama

`servers/loem/hollama.nix` runs [Hollama](https://github.com/fmaclen/hollama)
0.36.0 from its upstream container image, pinned by multi-architecture digest.
The container listens on `127.0.0.1:3080` through Docker's loopback port binding;
the private Tailnet Caddy proxy publishes it at `https://chat.loem.lferraz.dev`.
It has no sign-in, database, or persistent volumes and runs with a read-only
container filesystem. Conversations, connection settings, and preferences live
in each browser's `localStorage`, surviving page reloads and container restarts.
Clearing site data removes that browser's history; use Hollama's import/export
controls to keep or move it.

The root page in `common/hollama/index.html` seeds a CLIProxyAPI connection on
first visit and verifies model discovery before opening the chat interface.
It preserves existing browser connection settings. Browser requests to `/v1/*`
are proxied directly to `http://127.0.0.1:8317`, including `/v1/models`, avoiding
CPA Manager Plus's model-list routing on the `llm` hostname. This keeps the API
on the same origin as the UI without CORS configuration. CLIProxyAPI currently
needs no client key; Hollama supplies its non-secret SDK placeholder. No model
filter is configured, so all proxy models can be selected, including newly added
ones after model discovery refreshes.

Hollama supports text, vision, and streamed reasoning responses. Its OpenAI-compatible
chat path sends the selected model and message history with streaming enabled;
advanced sampling controls are currently specific to Ollama. It provides no
function/tool-calling workflow. The interface is suited to quick conversational
proxy checks rather than exhaustive endpoint conformance tests.

There is no Hollama state to register for machine backups. CLIProxyAPI's separate
request/exchange retention remains governed by its own configuration. Any old
`/var/lib/open-webui` data is left untouched; the OpenWebUI service is no longer
part of the host configuration.

Build before the separate user activation step:

```bash
nix build .#nixosConfigurations.loem.config.system.build.toplevel --no-link
```

After activation, validate on `loem`:

```bash
systemctl is-active cli-proxy-api.service docker-hollama.service
curl --fail http://127.0.0.1:3080/api/metadata
curl --fail https://chat.loem.lferraz.dev/v1/models
journalctl -u docker-hollama.service -u cli-proxy-api.service --since '10 minutes ago'
```

From a Tailnet-connected browser, open the chat URL and check that it goes straight
to the interface without sign-in. Select a model and send a short prompt. Verify
that its response streams and the exchange appears in CPA Manager Plus at
`https://llm.loem.lferraz.dev`. Reload the page and confirm the conversation remains
in that browser. Start a new chat after adding a proxy model to refresh discovery.
Model discovery alone does not prove inference works.

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
