final: pkgs: let
  jetbrains = pkgs.master.callPackage ./jetbrains {};

  globalPlugins = [
    "164"
    "17718"
  ];

  overrides = {
    # https://www.jetbrains.com/webstorm/nextversion
    webstorm = {};
    # https://www.jetbrains.com/go/nextversion
    goland = {};
    # https://www.jetbrains.com/pycharm/nextversion
    pycharm-professional = {};
    # https://www.jetbrains.com/datagrip/nextversion
    datagrip = {
      plugins = ["8182-beta"];
    };
    # https://www.jetbrains.com/rust/nextversion
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
