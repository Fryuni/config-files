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

## CLIProxyAPI

`servers/loem/cli-proxy-api.nix` runs CLIProxyAPI on `127.0.0.1:8317`, and
`servers/loem/cpa-manager-plus.nix` runs CPA Manager Plus on `127.0.0.1:18317`.
The private Tailnet Caddy proxy publishes each on its own hostname, without
path-specific routing: `https://llm.loem.lferraz.dev` is the API only, and
`https://llm-manager.loem.lferraz.dev` serves the manager and its UI. CPA Manager
Plus reaches CLIProxyAPI through the loopback listener.

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
are proxied directly to `http://127.0.0.1:8317`, including `/v1/models`. This
keeps the API on the same origin as the UI without CORS configuration. CLIProxyAPI currently
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
`https://llm-manager.loem.lferraz.dev`. Reload the page and confirm the
conversation remains in that browser. Start a new chat after adding a proxy model to refresh discovery.
Model discovery alone does not prove inference works.

## ZeroClaw

`servers/rpi3/zeroclaw.nix` runs one [ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw)
instance, `zeroclaw-claw.service`, on `rpi3` through upstream's NixOS module. The module
comes from the source-only `zeroclaw` flake input; keep its tag at the version of nixpkgs'
`zeroclaw` package. State lives in `/var/lib/zeroclaw-claw`.
The service PATH includes Bash: ZeroClaw validates its default `sh` runtime before
starting channel workers, even when no shell tool has been used. It also includes `git`,
`curl`, `gws` and `which` for `zeroclaw doctor`, which finds CLI tools by running `which`.
The `zeroclaw-claw` user lingers only so doctor's `loginctl` check succeeds.
ZeroClaw 0.8.4's dashboard drops the provider alias from model catalog requests. The
dashboard proxy rewrites `provider=custom` to `provider=custom.loem` so the model picker
uses Loem's live catalog. Revisit this mapping before adding another custom endpoint,
or remove it when upstream sends the full provider reference.

- **Model:** the `assistant` agent uses `gpt-6.1-sol` with high reasoning and requests fast mode
  through Loem's CLIProxyAPI at `https://llm.loem.lferraz.dev/v1`. The provider's
  `provider_extra` sends `reasoning_effort = "high"` and `service_tier = "priority"`.
  ZeroClaw 0.8.4's built-in reasoning filter does not recognize GPT 6, so use these
  explicit parameters. ZeroClaw only trusts public roots, so the provider
  points `tls_ca_cert_path` at the Tailnet CA.
- **Matrix:** the agent logs in as `@claw:lferraz.com` on `https://matrix.lferraz.com`
  with `MATRIX_PASSWORD` from `secrets/rpi3/zeroclaw-env`. It only accepts messages from
  `@luiz:lferraz.com`, because the homeserver federates. On every start it recovers E2EE
  with the account's Secure Backup key, `MATRIX_RECOVERY_KEY` in the same file. This
  cross-signs its device, so clients send it room keys instead of withholding them as
  `m.unverified`. ZeroClaw cannot create the key. To bootstrap one, sign in to Element
  as `@claw` and set up recovery there.
- **Executor:** the agent gets Loem's [Executor](services.md#executor) MCP tools
  (`executor__*`) over the Tailnet at `http://executor.loem.lferraz.dev/mcp`, since its MCP
  client only trusts public CAs. It authenticates with an organization-scoped Executor
  personal access token in `secrets/rpi3/executor-env` (`EXECUTOR_TOKEN=...`). Create a new
  one under Account settings → Tokens to rotate it.
- **Memory embeddings:** hybrid memory search embeds through OpenRouter with
  `perplexity/pplx-embed-v1-0.6b` (1024 dimensions), using the shared
  `secrets/ai/openrouter` key rekeyed for `rpi3`. The key is a raw file rather than
  `KEY=VALUE`, so it reaches the unit through `LoadCredential=`, and an `ExecStartPre`
  step writes it into `config.toml`. If you change the model or dimensions, run
  `zeroclaw memory reindex --config-dir /var/lib/zeroclaw-claw` as `zeroclaw-claw`.
- **Skills and memory:** skills may include scripts, and the agent creates skills from
  successful multi-step tasks (with a reflection call) and improves them after use. All
  skills live in the single `default` bundle. Typed memory is on. Heartbeat targets the
  `assistant` agent with adaptive pacing but stays disabled.
- **Approvals:** the agent uses upstream's YOLO preset as its `yolo` risk profile. It runs
  every tool and shell command without asking, with no forbidden paths or command
  allowlist. The systemd hardening still confines it to the `zeroclaw-claw` user, a
  read-only system, and no home directories. Only `@luiz:lferraz.com` can reach it on
  Matrix. Executor's own approval rules still apply to Executor tools.
- **Dashboard:** `https://claw.rpi3.lferraz.dev` proxies the gateway on `127.0.0.1:42617`,
  like the generic port hostnames. Gateway pairing stays on. Through Caddy every request
  arrives from loopback, so the gateway's local-only `/admin/*` routes (pairing codes,
  shutdown, reload) are open to the Tailnet, the same as other services on the private
  network.

`rpi3` also has the Google Workspace CLI, `gws`, installed system-wide. ZeroClaw's
`[google_workspace]` tool is not enabled.

The module rewrites `config.toml` from Nix on every start. Changes made in the dashboard's
config editor last only until the next restart. Paired dashboard tokens, which the gateway
stores in that file, are saved before the rewrite and restored after it.

Reasoning and fast mode are configured in the provider's `provider_extra` attribute
in `servers/rpi3/zeroclaw.nix`. Config → Model providers → custom / loem → Advanced →
Provider Extra displays them, but ZeroClaw 0.8.4 saves edits to this field as a string,
which its provider ignores. Use Nix to change these values until upstream fixes the
editor. They apply to every agent using `custom.loem`, rather than individual messages.
A different model may require different extra parameters; remove GPT-specific values
when switching to another model family.

Fast mode uses the API's `priority` service tier. Validation confirmed that Loem forwards
both the body parameter and `X-Codex-Routing-Hint: model=gpt-6.1-sol;tier=priority` to
the ChatGPT backend. The completed response confirmed high reasoning but reported
`service_tier: default`, including when directly requesting `fast` or `priority` from
the proxy. Fast-mode service is therefore requested, but not confirmed by the upstream
response; do not infer it from the configured value or response speed alone.

First deployment:

1. Create the bot account with the generated password. Print it on a machine with the
   master identity:
   `nix shell nixpkgs#age -c age -d -i ~/.ssh/id_ed25519 secrets/rpi3/zeroclaw-env`.
   Then, in the Tuwunel admin room, send `!admin users create-user claw <password>`.
2. Deploy with `just deploy rpi3`, then check `journalctl -u zeroclaw-claw` on `rpi3`.
3. Open the dashboard and pair; it fills in the initial pairing code. To pair another
   browser later, run `zeroclaw gateway get-paircode --new --port 42617` on `rpi3`.
4. From `@luiz:lferraz.com`, start a direct chat with `@claw:lferraz.com`. ZeroClaw does
   not accept invites by itself, so join it from the admin room:
   `!admin users force-join-room @claw:lferraz.com <!room-id>` (the internal room ID from
   Element's room settings, under Advanced).

The bot has no recovery key, so its messages show as coming from an unverified device.
Encrypted chats still work. If the Matrix state in `/var/lib/zeroclaw-claw` is lost, the
bot logs in again with a new device, and older encrypted messages stay unreadable to it.

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
