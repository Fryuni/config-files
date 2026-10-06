# Notebook desktop

[Project overview](../README.md) · [Architecture](architecture.md)

These notes cover the graphical environment on `note`. The system configuration lives in
`nixos/` and `nixos/notebook/`; Home Manager's UI configuration lives in `nix-home/ui/`.

## Desktop session

SDDM defaults to the i3 X11 session; Plasma remains selectable as the fallback desktop.

The desktop session is defined in `nix-home/ui/xsession.nix` and included through
`nix-home/notebook.nix`. See the
[i3 keybinding migration review](../common/docs/i3-keybinding-migration.md) for binding
details.

## Desktop access from shells

`nix-home/ui/terminal-environment.nix` connects every new Zsh shell to the active local
desktop using the graphical environment held by the systemd user manager. This includes
SSH login shells, noninteractive SSH commands, and new Herdr panes; their child
processes inherit the display, X authentication path, user D-Bus address, runtime
directory, and desktop type. The local desktop takes precedence over an SSH-forwarded
display.

Only these desktop variables are imported, and startup leaves the environment
unchanged when no graphical session is active. This module is notebook-only; server
shells are unaffected.

After applying Home Manager, open a new shell; existing shells
can refresh with `exec zsh`. Already-running processes retain their old environment, so
restart a Herdr server started without desktop access when convenient. Each new shell
reads the current authentication path again after a graphical re-login.

## Tray icons

Polybar uses an XEmbed tray. The `snixembed` user service bridges modern
StatusNotifierItem icons (including Slack and OpenWhispr) into it and acquires the D-Bus
watcher before Vicinae starts. The package overlay patches snixembed's ARGB pixel stride
so bitmap-only icons render correctly.

See [AI tools](ai-tools.md#t3-code) for the T3 backend’s graphical-session lifecycle.
