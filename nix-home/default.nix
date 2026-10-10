{
  config,
  lib,
  ...
}: {
  # Let home-manager manage itself.
  home.stateVersion = "26.05";
  home.enableNixpkgsReleaseCheck = false;

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

  services.machineBackups = {
    exclude = map (path: "${config.home.homeDirectory}/${path}") [
      ".cache"
      ".npm/_cacache"
      ".npm/_logs"
      ".cargo/registry"
      ".cargo/target"
    ];
    directories = lib.mkIf config.services.syncthing.enable [
      {
        name = "syncthing";
        paths = ["${config.xdg.stateHome}/syncthing"];
        scopes = ["home" "services"];
        units = [
          {
            name = "syncthing.service";
            type = "user";
          }
        ];
      }
      {
        # Home Manager also supports Syncthing's pre-XDG-state location.
        name = "syncthing-legacy-config";
        paths = ["${config.xdg.configHome}/syncthing"];
        optional = true;
        scopes = ["home" "services"];
        units = [
          {
            name = "syncthing.service";
            type = "user";
          }
        ];
      }
    ];
  };

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
