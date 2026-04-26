{...}: {
  # Let home-manager manage itself.
  home.stateVersion = "26.05";

  home.username = "lotus";
  home.homeDirectory = "/home/lotus";

  imports = [
    ./modules
    ./secrets.nix
    ./nix.nix
  ];

  # home.packages = [
  #   inputs.home-manager.packages.${builtins.currentSystem}.docs-html
  # ];

  services.syncthing.enable = true;

  # Disable manual generation to work around upstream home-manager bug:
  # both html and manpages depend on hmOptionsDocs.optionsJSON, whose
  # transformOptions uses toString on nixpkgs declaration paths, stripping
  # string context and causing the "options.json references store path
  # without proper context" warning. The manual is available online at
  # https://nix-community.github.io/home-manager/
  manual = {
    html.enable = false;
    manpages.enable = false;
  };
}
