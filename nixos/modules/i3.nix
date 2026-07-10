{pkgs, ...}: let
  homeManagerI3Session =
    (pkgs.writeTextFile {
      name = "home-manager-i3-xsession";
      destination = "/share/xsessions/home-manager-i3.desktop";
      text = ''
        [Desktop Entry]
        Type=XSession
        Name=Home Manager i3
        Exec=/home/lotus/.hm-xsession
      '';
    })
    // {
      providedSessions = ["home-manager-i3"];
    };
in {
  services.xserver.windowManager.i3.enable = true;

  services.displayManager.sessionPackages = [homeManagerI3Session];

  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.common.default = ["gtk"];
  };

  environment.sessionVariables = {
    GTK_THEME = "Adwaita:dark";
    COLOR_SCHEME = "dark";
  };

  environment.systemPackages = with pkgs; [
    i3lock-color
    polkit_gnome
  ];

  security.polkit.enable = true;
  security.pam.services.i3lock = {};
}
