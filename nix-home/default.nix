{inputs, ...}: {
  # Let home-manager manage itself.
  home.stateVersion = "22.05";
  programs.home-manager.enable = true;

  home.username = "lotus";
  home.homeDirectory = "/home/lotus";

  imports = [
    ./ui
    ./nix.nix
  ];

  # home.packages = [
  #   inputs.home-manager.packages.${builtins.currentSystem}.docs-html
  # ];

  services.syncthing.enable = true;
}
