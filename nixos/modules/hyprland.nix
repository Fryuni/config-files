{
  pkgs,
  lib,
  ...
}: {
  # Enable Hyprland compositor
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # XDG Portal for Wayland
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  # Environment variables for Wayland
  environment.sessionVariables = {
    # Wayland
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";

    # Qt Wayland
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

    # GTK
    GDK_BACKEND = "wayland,x11";
    GTK_THEME = "Adwaita:dark";

    # Color scheme preference
    COLOR_SCHEME = "dark";

    # SDL
    SDL_VIDEODRIVER = "wayland";

    # Clutter
    CLUTTER_BACKEND = "wayland";

    # Firefox/Mozilla
    MOZ_ENABLE_WAYLAND = "1";

    # Electron apps
    NIXOS_OZONE_WL = "1";
  };

  # Packages needed for Hyprland
  environment.systemPackages = with pkgs; [
    # Wayland utilities
    wl-clipboard
    wlr-randr
    wev
    slurp
    grim

    # Authentication
    polkit_gnome
  ];

  # Enable polkit for authentication dialogs
  security.polkit.enable = true;

  # Enable PAM for swaylock
  security.pam.services.swaylock = {};
}
