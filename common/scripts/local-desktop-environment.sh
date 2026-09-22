# Used by the notebook's Zsh startup via writeShellApplication.
# Query this user's local manager even when the caller has no runtime directory
# (e.g. a system service) or has inherited a different D-Bus address.
XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

if ! systemctl --user --quiet is-active graphical-session.target; then
  exit 0
fi

systemctl --user --output=json show-environment | jq -r '
  select(.DISPLAY != null and .DISPLAY != "") |
  {
    DISPLAY,
    XAUTHORITY: (.XAUTHORITY // (env.HOME + "/.Xauthority")),
    XDG_RUNTIME_DIR: env.XDG_RUNTIME_DIR,
    DBUS_SESSION_BUS_ADDRESS: env.DBUS_SESSION_BUS_ADDRESS,
    XDG_SESSION_TYPE: (.XDG_SESSION_TYPE // "x11"),
    XDG_CURRENT_DESKTOP,
    XDG_SESSION_DESKTOP
  } |
  to_entries[] |
  select(.value != null) |
  "export \(.key)=\(.value | @sh)"
'
