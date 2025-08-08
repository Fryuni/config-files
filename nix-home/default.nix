{inputs, pkgs, ...}: {
  # Let home-manager manage itself.
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  imports = [
    ./nix.nix
  ];

  # home.packages = [
  #   inputs.home-manager.packages.${builtins.currentSystem}.docs-html
  # ];

  # services.syncthing.enable = true;

  # home.file.".background-image".source = ../common/wallpaper/wallpaper.png;

  xdg.enable = true;

programs.ssh.matchBlocks."notebook.lferraz.dev" = {
proxyCommand = "${pkgs.cloudflared} access ssh --hostname %h";
};

  manual = {
    html.enable = true;
    manpages.enable = true;
  };
}
