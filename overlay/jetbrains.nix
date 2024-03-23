final: pkgs: let
  jetbrains = pkgs.master.jetbrains;
  # jetbrains = pkgs.master.callPackage ./jetbrains {};

  globalPlugins = [
    "164" # IdeaVIM
    "17718" # GitHub Copilot
    # "9836" # Randomness
    # "7425" # Wakatime
    # "7499" # Git Toolbox
  ];

  overrides = {
    webstorm = {
      # plugins = [
      #   "20959" # Astro
      # ];
    };
    goland = {};
    pycharm-professional = {};
    datagrip = {};
    rust-rover = {};
  };

  overrideFn = name: {
    noGlobalPlugins ? false,
    plugins ? [],
  }: let
    package = jetbrains.${name};
    idePlugins =
      if noGlobalPlugins
      then plugins
      else plugins ++ globalPlugins;
  in
    jetbrains.plugins.addPlugins package idePlugins;

  overridePkgs = builtins.mapAttrs overrideFn overrides;
in {
  jetbrains = jetbrains // overridePkgs;
}
