{inputs, ...}: {
  # Let home-manager manage itself.
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  home.username = "lotus";
  home.homeDirectory = "/home/lotus";

  imports = [
    ./ui
    ./modules
    ./secrets.nix
    ./nix.nix
  ];

  # home.packages = [
  #   inputs.home-manager.packages.${builtins.currentSystem}.docs-html
  # ];

  services.syncthing.enable = true;

  home.file.".background-image".source = ../common/wallpaper/wallpaper.png;

  xdg.enable = true;

  manual = {
    html.enable = true;
    manpages.enable = true;
  };
}
