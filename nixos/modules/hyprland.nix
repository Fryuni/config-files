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
    config = {
      common = {
        default = ["gtk"];
      };
      hyprland = {
        default = ["hyprland" "gtk"];
      };
    };
  };

  # Global environment variables (apply to all sessions)
  environment.sessionVariables = {
    # GTK theme (works for both X11 and Wayland)
    GTK_THEME = "Adwaita:dark";

    # Color scheme preference
    COLOR_SCHEME = "dark";

    # Electron apps - use Wayland when available (safe for X11 too)
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
