{pkgs, ...}: {
  # Enable fcitx5 for proper input method support on Wayland
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
    ];
  };

  gtk = {
    enable = true;

    # Enable dark theme preference
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };

    # GTK apps will use fcitx5 for input
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    # GTK4 needs the theme name in settings.ini even though libadwaita uses dconf
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-theme-name = "Adwaita-dark";
    };
  };

  # dconf settings for GNOME applications like Nautilus
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
    };
  };
}
