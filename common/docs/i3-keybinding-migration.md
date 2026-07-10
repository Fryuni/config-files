# i3/X11 Keybinding Migration

This is the review record for the migration from the removed
`nix-home/ui/hyprland.nix` module to `nix-home/ui/xsession.nix`. `Super` means
`Mod4`. The i3 configuration is the source of truth; this document records the
intentional departures from both the former Hyprland configuration and i3's
sample defaults.

> There is no literal **Vc9** integration anywhere in this repository. In this
> migration, references to “Vc9” mean the implemented **Vicinae** launcher:
> `vicinae toggle` on `Super+Space`.

## Session and source of truth

- SDDM starts `none+i3` by default on X11; Plasma remains an SDDM alternative.
- Home Manager imports the X11 desktop from `nix-home/ui/default.nix`, which
  imports `nix-home/ui/xsession.nix`; this file is the binding implementation.
- The former Wayland implementation is the tracked pre-migration
  `nix-home/ui/hyprland.nix`. Its binding list is the comparison baseline,
  rather than the old guide or planned configuration.
- `nix-home/ui/xsession.nix` uses i3 with 3px inner/6px outer gaps, 2px borders,
  `autotiling`, and Polybar. These resemble the previous geometry, but i3's
  container tree is not Hyprland's dwindle layout.

## Preserved key intent

The following bindings retain their former shortcut and user-visible intent.
Where the command is named, it is the exact current i3 command.

| Shortcut | Current i3 action | Former Hyprland action | Review result |
| --- | --- | --- | --- |
| `Super+Enter` | launch Ghostty | launch Ghostty | Preserved. |
| `Super+Shift+Enter` | `ghostty -e t` | `ghostty -e t` | Preserved. |
| `Super+Q` | close focused window | `killactive` | Equivalent close request. |
| `Super+N` | launch Thunar | launch Thunar | Preserved. |
| `Super+Shift+N` | launch `nm-connection-editor` | launch `nm-connection-editor` | Preserved. |
| `Super+D` | Rofi `drun` | Rofi `drun` | Preserved launcher choice; see i3-default overrides. |
| `Super+Space` | `vicinae toggle` | `vicinae toggle` | Preserved Vicinae launcher toggle. |
| `Super+B` | launch Firefox Beta | launch Firefox Beta | Preserved. |
| `Super+Shift+B` | launch Google Chrome | launch Google Chrome | Preserved. |
| `Super+F` | `fullscreen toggle` | true fullscreen (`fullscreen, 0`) | Preserved fullscreen intent. |
| `Super+V` | `floating toggle` | `togglefloating` | Preserved. |
| `Super+C`, `Super+X`, `Super+Z` | Rofi calculator, power menu, emoji picker | same Rofi modes | Preserved. |
| Arrow keys and `Super+H/J/K/L` movement | focus/move in the matching left/down/up/right directions | `movefocus`/`movewindow` in those directions | Preserved except for the `Super+L` focus collision below. |
| `Super+Shift+Left/Right/Up/Down` and `Super+Shift+H/J/K/L` | move container in direction | move window in direction | Preserved directional intent. |
| `Super+1`–`Super+0` | workspace 1–10 | workspace 1–10 | Preserved. |
| `Super+Shift+1`–`Super+Shift+0` | move container to workspace 1–10 | move window to workspace 1–10 | Preserved. |
| `Super+[` / `Super+]` | previous / next workspace | `e-1` / `e+1` workspace | Preserved direction. |
| `Super+A` | `workspace back_and_forth` | previous workspace | Preserved last-workspace intent. |
| `Super+R`, then arrows or `H/J/K/L` | resize mode; `Return`/`Escape` exits | resize submap; `Return`/`Escape` resets | Preserved modal controls; repeat behavior differs. |
| `XF86Audio*` / `XF86MonBrightness*` | same `pamixer`, `playerctl`, and `brightnessctl` operations | same operations | Commands preserved; lock-screen handling differs. |

## Explicit i3-default overrides

This table is exhaustive for the i3 sample-default bindings whose default
meaning is replaced or intentionally absent in the current configuration.
`Mod1` in the upstream sample is `Mod4` here. A blank current action means the
sample binding is not configured, not that i3 supplies a fallback binding.

| i3 sample shortcut and default | Current action | Reason / migration consequence |
| --- | --- | --- |
| `Super+Return` — terminal | Ghostty | Chooses the configured terminal rather than `i3-sensible-terminal`; preserves the former Ghostty binding. |
| `Super+Shift+Q` — close focused window | `ghostty -e t` | The former Hyprland terminal-with-`t` binding wins; close moved to `Super+Q`. |
| `Super+D` — dmenu | Rofi `drun` | Preserves the former Rofi launcher. |
| `Super+H` — horizontal split | focus left | Preserves Hyprland's vim-style focus cluster. |
| `Super+J` — focus left | focus down | Preserves Hyprland's `J` direction. |
| `Super+K` — focus down | focus up | Preserves Hyprland's `K` direction. |
| `Super+L` — focus up | lock screen | Resolves the former duplicate `Super+L`; right focus is `Super+semicolon`. |
| `Super+Shift+J` — move left | move down | Preserves Hyprland's directional cluster. |
| `Super+Shift+K` — move down | move up | Preserves Hyprland's directional cluster. |
| `Super+Shift+L` — move up | move right | Preserves Hyprland's directional cluster. |
| `Super+Shift+semicolon` — move right | not bound | `Super+Shift+L` is the preserved right-move chord. |
| `Super+V` — vertical split | floating toggle | Retains the former Hyprland floating-toggle chord. |
| `Super+S` — stacking layout | `layout toggle split` | Retains the former split-direction control as closely as i3 can. |
| `Super+W` — tabbed layout | `focus next` | Retains the former next-group-tab chord; it now cycles i3 focus, not a Hyprland group. |
| `Super+E` — default layout | floating toggle | Replaces the former Hyprland pseudotile chord with i3's closest window-state control. |
| `Super+Shift+Space` — floating toggle | not bound | Floating is deliberately on `Super+V` and `Super+E`. |
| `Super+Space` — toggle focus between floating and tiling | `vicinae toggle` | Preserves the launcher. |
| `Super+A` — focus parent | `workspace back_and_forth` | Preserves the former workspace-history chord. |
| `Super+Shift+C` — reload configuration | not bound | No migration binding is configured. |
| `Super+Shift+R` — restart i3 | not bound | `Super+R` is instead the former resize-mode entry chord. |
| `Super+Shift+E` — exit i3 | not bound | Exit is intentionally `Super+M`, matching the former core binding. |

`Super+F`, workspace number bindings, arrow-key focus/move bindings,
`Super+semicolon` focus-right, and the scratchpad chords have compatible i3
meanings and are not overrides of different behavior.

## Hyprland self-conflicts: selected i3 resolutions

The removed Hyprland binding array defined two actions for each of the following
shortcuts. i3 has one current meaning for each; the discarded action is not
silently available on another chord unless shown.

| Duplicate former shortcut | Former actions | Selected i3 action | Deliberately not retained |
| --- | --- | --- | --- |
| `Super+L` | `swaylock`; focus right | `i3lock -c 252a34` | Focus right moves to `Super+semicolon`. |
| `Super+M` | exit; `swapwithmaster` | `exit` | `swapwithmaster`; i3 has no master-layout counterpart. |

## Changed or non-equivalent bindings

These are every former Hyprland binding whose result is different, unavailable,
or only an approximation in the current i3 implementation.

| Former shortcut | Current i3 result | Difference to review |
| --- | --- | --- |
| `Super+Shift+F` | `fullscreen toggle global` | Replaces Hyprland's maximize-with-bar (`fullscreen, 1`). Global fullscreen is the closest configured X11 alternative; it is not maximize while retaining the bar. |
| `Super+P` | `sticky toggle` | Replaces Hyprland `pin`. It keeps a floating window visible across i3 workspaces, rather than Hyprland's pin behavior. |
| `Super+Shift+V` | `copyq menu` | Replaces `cliphist list | rofi -dmenu | cliphist decode | wl-copy`; see X11 clipboard backend changes. |
| `Print` | `flameshot gui` | Replaces the Wayland `flameshot-copy` wrapper that captured raw PNG and explicitly published it through `wl-copy`. |
| `Shift+Print` | `flameshot full -c` | Replaces `flameshot full`; X11 now asks Flameshot to copy the full capture. |
| `Super+Print` | `flameshot screen -c` | Replaces `flameshot screen`; X11 now asks Flameshot to copy the screen capture. |
| `Super+L` | `i3lock -c 252a34` | Replaces `swaylock`; it also wins the duplicate focus-right conflict. |
| `Super+S` | `layout toggle split` | i3 toggles the selected container's split orientation. It is not Hyprland dwindle's `togglesplit` in a binary-tree layout. |
| `Super+E` | `floating toggle` | Replaces Hyprland pseudotile. i3 has no tiled pseudotile state; floating is the chosen approximation. |
| `Super+G` | `layout toggle tabbed` | Replaces Hyprland `togglegroup`. i3 tabbed containers are not Hyprland groups and have no former groupbar behavior. |
| `Super+W` / `Super+Shift+W` | focus next / focus previous | Replaces next/previous *active tab in a Hyprland group* with general i3 focus cycling. |
| `Super+M` | exit | The competing `swapwithmaster` binding is removed; i3 has no master layout. |
| `Super+-` | `scratchpad show` | Replaces the named Hyprland special workspace `magic` with i3's scratchpad. |
| `Super+Shift+-` | `move scratchpad` | Replaces moving to `special:magic`. |
| `Super+Button4` / `Super+Button5` | previous / next workspace | Replaces Hyprland `mouse_down`/`mouse_up` workspace events with explicit X11 wheel buttons. Verify physical scroll direction after login. |
| `Super+Ctrl+arrows` and `Super+Ctrl+H/J/K/L` | one 20px/20ppt resize per event | Replaces repeatable Hyprland `binde resizeactive` bindings. |
| `Super+R` resize mode | ordinary i3 resize commands | The same entry/exit keys and directions exist, but the Hyprland repeatable submap is not present. |
| `Super` + left/right mouse drag | no tiled-container equivalent | Hyprland `bindm` moved/resized tiled windows. i3's `floating.modifier = Mod4` supports modifier dragging for floating windows only. |
| `XF86Audio*` / brightness keys | same commands | Hyprland declared the media bindings in `bindel`/`bindl` (including lock-aware variants). i3 configures ordinary X11 keybindings; no lock-layer equivalent is configured. |

The former commented `Super+grave` hyprexpo overview was not an active
Hyprland binding and has no i3 overview binding. Hyprland-specific dwindle
settings, master layout settings, groupbar styling, touchpad/Wayland input
settings, and drag-to-resize tiled windows also have no direct i3 counterpart.
Do not treat the old guide's overview, dwindle, group, gesture, or Wayland-only
claims as current behavior.

## Wayland-to-X11 backend changes

| Concern | Former Hyprland backend | Current X11/i3 backend | What to verify |
| --- | --- | --- | --- |
| Clipboard history | `wl-paste` watchers, `cliphist`, `wl-copy` | `services.copyq` and `copyq menu` | Copy text and an image, then open `Super+Shift+V`; ensure both are available. |
| Screenshots | Flameshot/`grim` Wayland adapter and `flameshot-copy` wrapper | Native X11 Flameshot, which owns the X clipboard | Exercise all three screenshot chords and paste each capture into an X11 application. |
| Lock | `swaylock` | `i3lock -c 252a34` | `Super+L` must lock and successfully unlock. |
| Notifications | SwayNotificationCenter (`swaync`) | `services.dunst` | Trigger an ordinary desktop notification and check it renders. |
| Wallpaper and bar | commented `swww`; Waybar `hyprland/*` modules | `feh --bg-fill` at startup; Polybar with i3/xwindow modules | Confirm wallpaper, workspace indicators, focused title, tray, audio, and date after login. |
| Rofi and launcher windows | Wayland compositor session | X11 i3 session | `Super+D` should open Rofi drun; `Super+Space` should show/hide Vicinae as an X11-managed launcher window. |
Vicinae's current managed configuration supplies a client-side-decorated launcher window and contains no `layer_shell` or Hyprland-specific extension setting. Its daemon is part of `graphical-session.target`; the i3 binding and normal X11 window management provide the retained toggle behavior.


### OpenWhispr X11 integration

The current X11 configuration starts OpenWhispr from i3 startup and also
installs the existing XDG autostart entry in `nix-home/ui/default.nix`. Its i3
rules for `[class="open-whispr" title="Voice Recorder"]` are both required:
`no_focus` prevents the recording overlay from taking the previous target's
focus, and `floating enable, border none` keeps it out of the tiling tree.

The package overlay includes `ydotool` and `xdotool`, and patches its paste-tool
candidate order to `ydotool`, then `xdotool`, then `wtype`. The current
`ydotoold` user service is wanted by `graphical-session.target`. After
recording, verify that the transcript is pasted into the window that was focused
before the Voice Recorder overlay appeared; do not accept paste into the
overlay as a successful test.

## Login review checklist

After selecting the default i3 session in SDDM and logging in:

1. Confirm the X11 i3 session, Polybar, wallpaper, tray, and Dunst notification
   are present; select Plasma from SDDM separately only to confirm the fallback
   remains available.
2. Press `Super+Enter` for Ghostty, `Super+B` for Firefox Beta, `Super+D` for
   Rofi, and `Super+Space` twice to show and hide Vicinae.
3. Use `Super+L` to lock/unlock, then verify `Super+semicolon` focuses right
   and `Super+M` exits only when intentionally testing logout behavior.
4. Capture with `Print`, `Shift+Print`, and `Super+Print`; paste every result
   into an X11 application. Open CopyQ with `Super+Shift+V` and restore an item.
5. Create multiple windows and test directional focus/move, split/tabbed
   layouts, floating, sticky, scratchpad, workspaces, wheel workspace cycling,
   resize mode, and media/brightness keys. Check the documented
   approximations—notably `Super+E`, `Super+G`, and `Super+Shift+F`.
6. Start a dictation with OpenWhispr. Confirm its Voice Recorder overlay remains
   unfocused/floating/borderless and that its completed text pastes into the
   previously focused X11 target.
