{inputs, ...}: {
  # Let home-manager manage itself.
  home.stateVersion = "22.05";
  programs.home-manager.enable = true;

  imports = [
    ./ui
    ./nix.nix
  ];

  # home.packages = [
  #   inputs.home-manager.packages.${builtins.currentSystem}.docs-html
  # ];

  # services.syncthing.enable = true;

  # home.file.".background-image".source = ../common/wallpaper/wallpaper.png;
}
