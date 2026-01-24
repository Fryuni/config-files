# Hyprland Keybindings Guide

This document describes the keyboard shortcuts for navigating and managing windows in Hyprland with the dwindle tiling layout.

> **Note:** `Super` refers to the Windows/Meta key.

---

## Quick Reference

| Action | Keybinding |
|--------|------------|
| Terminal | `Super + Enter` |
| App Launcher | `Super + D` |
| Close Window | `Super + Q` |
| Fullscreen | `Super + F` |
| Toggle Float | `Super + V` |
| Lock Screen | `Super + L` |

---

## Core Applications

| Keybinding | Action |
|------------|--------|
| `Super + Enter` | Open terminal (Ghostty) |
| `Super + D` | Open app launcher (Rofi) |
| `Super + B` | Open browser (Chrome) |
| `Super + N` | Open file manager (Nautilus) |
| `Super + L` | Lock screen |
| `Super + Q` | Close active window |
| `Super + M` | Exit Hyprland |

---

## Window Navigation

### Focus Movement

Move focus between tiled windows using arrow keys or vim-style keys:

| Keybinding | Action |
|------------|--------|
| `Super + H` / `Super + Left` | Focus left |
| `Super + L` / `Super + Right` | Focus right |
| `Super + K` / `Super + Up` | Focus up |
| `Super + J` / `Super + Down` | Focus down |
| `Super + Tab` | Cycle to next window |
| `Super + Shift + Tab` | Cycle to previous window |

### Move Windows

Swap the active window with its neighbor:

| Keybinding | Action |
|------------|--------|
| `Super + Shift + H` / `Left` | Move window left |
| `Super + Shift + L` / `Right` | Move window right |
| `Super + Shift + K` / `Up` | Move window up |
| `Super + Shift + J` / `Down` | Move window down |

---

## Window Layout (Dwindle)

Hyprland uses the **dwindle** layout which automatically tiles windows in a binary tree pattern. Each new window splits the focused window's space.

### Layout Controls

| Keybinding | Action |
|------------|--------|
| `Super + S` | Toggle split direction (horizontal/vertical) |
| `Super + E` | Toggle pseudotile (window respects size hints) |
| `Super + M` | Swap focused window with master (first) |

### Window Groups (Tabs)

Group multiple windows together as tabs:

| Keybinding | Action |
|------------|--------|
| `Super + G` | Toggle group mode (create/dissolve tab group) |
| `Super + W` | Next tab in group |
| `Super + Shift + W` | Previous tab in group |

When windows are grouped, they appear as tabs at the top of the container.

---

## Window State

| Keybinding | Action |
|------------|--------|
| `Super + F` | Fullscreen (true fullscreen, hides bar) |
| `Super + Shift + F` | Maximize (keeps gaps and bar visible) |
| `Super + V` | Toggle floating mode |
| `Super + P` | Pin floating window (stays on all workspaces) |

---

## Resizing Windows

### Quick Resize (hold to repeat)

Hold these keys to continuously resize:

| Keybinding | Action |
|------------|--------|
| `Super + Ctrl + H` / `Left` | Shrink width |
| `Super + Ctrl + L` / `Right` | Grow width |
| `Super + Ctrl + K` / `Up` | Shrink height |
| `Super + Ctrl + J` / `Down` | Grow height |

### Resize Mode

Enter a dedicated resize mode for precise adjustments:

1. Press `Super + R` to enter resize mode
2. Use `H/J/K/L` or arrow keys to resize (20px per press)
3. Press `Escape` or `Enter` to exit resize mode

### Mouse Resize

| Action | How |
|--------|-----|
| Move window | `Super + Left Click` + drag |
| Resize window | `Super + Right Click` + drag |

---

## Workspaces

### Switch Workspace

| Keybinding | Action |
|------------|--------|
| `Super + 1-9, 0` | Switch to workspace 1-10 |
| `Super + [` | Previous workspace |
| `Super + ]` | Next workspace |
| `Super + A` | Last used workspace |
| `Super + \`` | Workspace overview (hyprexpo) |
| `Super + Scroll` | Scroll through workspaces |

### Move Window to Workspace

| Keybinding | Action |
|------------|--------|
| `Super + Shift + 1-9, 0` | Move window to workspace 1-10 |

### Scratchpad (Special Workspace)

A hidden workspace for temporary windows:

| Keybinding | Action |
|------------|--------|
| `Super + -` | Toggle scratchpad visibility |
| `Super + Shift + -` | Move window to scratchpad |

---

## Workspace Overview (hyprexpo)

Press **`Super + \``** (backtick) to enter workspace overview mode:

- See all workspaces in a 3-column grid
- Click on a workspace to switch to it
- Use keyboard to navigate
- Press `Escape` or `Super + \`` again to exit

---

## Screenshots (Flameshot)

| Keybinding | Action |
|------------|--------|
| `Print` | Screenshot region (interactive GUI) |
| `Shift + Print` | Screenshot all screens |
| `Super + Print` | Screenshot current monitor |

Flameshot provides an interactive editor where you can annotate, crop, and save/copy screenshots.

---

## Rofi Utilities

| Keybinding | Action |
|------------|--------|
| `Super + D` | App launcher |
| `Super + C` | Calculator |
| `Super + X` | Power menu (shutdown, reboot, suspend, etc.) |
| `Super + Z` | Emoji picker |
| `Super + Shift + V` | Clipboard history |

---

## Media Keys

These work globally, even on the lock screen:

| Key | Action |
|-----|--------|
| `Volume Up` | Increase volume 5% |
| `Volume Down` | Decrease volume 5% |
| `Mute` | Toggle mute |
| `Brightness Up` | Increase brightness 5% |
| `Brightness Down` | Decrease brightness 5% |
| `Play/Pause` | Toggle media playback |
| `Previous` | Previous track |
| `Next` | Next track |

---

## Touchpad Gestures

| Gesture | Action |
|---------|--------|
| 3-finger swipe left/right | Switch workspace |

---

## Window Rules (Automatic)

These windows automatically float:

- PulseAudio Volume Control (pavucontrol)
- Network Manager connection editor
- Picture-in-Picture windows (also pinned)
- GNOME Calculator
- Nautilus Properties dialogs

---

## Tips & Tricks

### Autotiling Behavior

The dwindle layout uses **smart splitting**:
- New windows automatically split based on available space
- Horizontal containers split vertically when tall
- Vertical containers split horizontally when wide
- Use `Super + S` to manually toggle split direction before opening a window

### Single Window Mode

When only one window is open on a workspace, gaps and borders are hidden for maximum screen space.

### Quick Window Management

1. **Swap windows**: Use `Super + Shift + H/J/K/L` to push windows around
2. **Create tabs**: Select windows and press `Super + G` to group them
3. **Pseudo-tile**: Press `Super + E` to let a window choose its own size within its tile

### Efficient Workflow

- Use `Super + 1-0` for quick workspace access
- Use `Super + A` to toggle between two workspaces
- Use `Super + -` for scratchpad (notes, music player, etc.)
- Use `Super + \`` for a bird's-eye view of all workspaces

---

## Configuration

The Hyprland configuration is managed through NixOS/Home Manager at:
- `nix-home/ui/hyprland.nix`

Key settings:
- **Gaps**: 3px inner, 6px outer
- **Border**: 2px with gradient (cyan to teal)
- **Animations**: Smooth slide animations
- **Blur**: Enabled with 8px radius
