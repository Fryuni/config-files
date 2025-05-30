final: pkgs: let
  jetbrains = pkgs.master.jetbrains;
  # jetbrains = pkgs.master.callPackage ./jetbrains {};

  globalPlugins = [
    "164" # IdeaVIM
    # "17718" # GitHub Copilot
    # "20540" # Codeium
    "9836" # Randomness
    "7425" # Wakatime
    "7499" # Git Toolbox
    # "22282" # JetBrains AI Assist
  ];

  overrides = {
    webstorm = {
      plugins = [
        # "20959" # Astro
      ];
    };
    goland = {};
    pycharm-professional = {};
    datagrip = {};
    rust-rover = {};
    idea-ultimate = {};
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
