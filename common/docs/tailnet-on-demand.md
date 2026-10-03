# On-demand Tailnet aliases

`services.lferrazTailnetAccess.proxy.aliases` accepts an attribute set for a
backend that should start when its named hostname is requested. Integer ports
and custom Caddy handler strings still work as before.

## System service

For an already declared `my-app.service` listening on `127.0.0.1:8080`:

```nix
{lib, ...}: {
  systemd.services.my-app.wantedBy = lib.mkForce [];

  services.lferrazTailnetAccess.proxy.aliases.my-app = {
    port = 8080;
    service = "my-app.service";
    idleTimeout = 15 * 60;
    startupTimeout = 90;
  };
}
```

Opening `https://my-app.note.lferraz.dev` runs `systemctl start my-app.service`,
waits for the TCP port, then forwards the original request. Simultaneous cold
requests share one startup. Failed startup or readiness timeout returns 503;
a later request can try again. The default startup deadline is 60 seconds.
TCP readiness means the port accepts connections; if the application needs a
stronger health check, put that check in a custom start script.

After 15 minutes without requests or open connections, the helper calls
`systemctl stop my-app.service`. Checks run every 30 seconds by default,
controlled by `services.lferrazTailnetAccess.proxy.idleCheckInterval`. Shutdown
may therefore lag the idle timeout by one check interval. Omitting
`idleTimeout` leaves the service running after its first use. `stopTimeout`
defaults to 30 seconds; unsuccessful stops are logged and retried at the next
check.

**Disable the backend's existing automatic activation.** The alias manages
requests, not the service definition. Clear its `wantedBy` (as above) and
remove any `requiredBy`, timer, socket, path, or other service dependency that
starts it automatically. Prefer a service module's own `autoStart = false`
option when available. Otherwise it may still start at boot, login, or on a
schedule. Disabling boot activation does not stop an already running service.

## User service

For an existing NixOS-declared user unit:

```nix
{lib, ...}: {
  systemd.user.services.my-app.wantedBy = lib.mkForce [];

  services.lferrazTailnetAccess.proxy.aliases.my-app = {
    port = 8080;
    service = "my-app.service";
    user = "lotus";
    idleTimeout = 15 * 60;
  };
}
```

The helper addresses that user's manager with
`systemctl --user --machine=lotus@.host`. It must already be running: either the
user has logged in, or the NixOS configuration enables
`users.users.lotus.linger = true`. Linger keeps the user manager available after
reboot without requiring the application itself to start. Applications that
need a graphical session still need a logged-in desktop and its environment.

For a Home Manager unit, clear
`systemd.user.services.my-app.Install.WantedBy = lib.mkForce []` in the Home
Manager configuration instead. Apply that configuration as well as the NixOS
alias configuration.

## Custom scripts

Use scripts when startup needs more than a single systemd unit:

```nix
{pkgs, ...}: {
  services.lferrazTailnetAccess.proxy.aliases.my-app = {
    port = 8080;
    startScript = ''
      ${pkgs.systemd}/bin/systemctl start my-app.service
      # Additional synchronous preparation or health checks go here.
    '';
    stopScript = ''
      ${pkgs.systemd}/bin/systemctl stop my-app.service
    '';
    idleTimeout = 15 * 60;
  };
}
```

Scripts run as root with `set -euo pipefail`; use absolute Nix store command
paths. They must be idempotent and return after starting or stopping a managed
service. Do not run the server in the foreground or background a daemon from
the script: launch it through its service manager. `service` and scripts are
mutually exclusive, and `user` applies only to `service`. A custom
`startScript` requires a `stopScript` if idle shutdown is enabled. Scripts are
stored in the Nix store, so reference secret files rather than embedding secrets.

## Activity and operation

The existing Caddy listener forwards these aliases over a private Unix socket
to `lferraz-tailnet-on-demand.service`. The helper binds no TCP listener and
accepts only configured alias names and ports. Root owns the socket directory;
the `caddy` group can connect to the socket but cannot change commands or state.
Caddy continues to handle TLS and CORS.

Activity includes preflight requests, ordinary HTTP requests, and open
streaming or WebSocket connections. The idle period starts again when the
last request completes. An open browser tab with a WebSocket, polling, or
background traffic can therefore keep the service running. Startup and shutdown
are serialized per alias; unrelated services proceed independently.

Only traffic through the named alias is tracked. Direct localhost access,
numeric port URLs, other aliases, and background work in the application are
not visible to this helper. Use one on-demand alias per backend: duplicate
ports or systemd units are rejected, and custom scripts must not control a
backend shared by another alias. Choose an idle timeout that suits any work
that continues after the HTTP response finishes.

The helper never starts a backend at boot. Ownership markers under
`/run/lferraz-tailnet-on-demand/state` survive helper restarts but clear on
reboot. After a helper restart, previously managed backends receive a fresh
idle period; proxy connections are disconnected by the restart. Removing an
alias or disabling the helper does not stop its backend; stop that service
separately when retiring an alias.

Inspect activity and failures with:

```bash
journalctl -u lferraz-tailnet-on-demand.service
```

Validate module configuration and helper behavior without applying it:

```bash
nix build .#checks.x86_64-linux.tailnet-access-module
```

The helper uses Go's [HTTP reverse proxy](https://pkg.go.dev/net/http/httputil#ReverseProxy)
behind Caddy's [Unix-socket upstream support](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy).
