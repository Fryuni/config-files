final: pkgs: let
  inherit (pkgs.master) jetbrains;

  globalPlugins = [
    "164"
    "17718"
  ];

  overrides = {
    # https://www.jetbrains.com/webstorm/nextversion
    webstorm = rec {
      version = "233.10527.23";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-yx+rDIP+Vyn7TutCz+Fe5pwCFfePDfMC9ySLH96NpX0=";
    };
    # https://www.jetbrains.com/go/nextversion
    goland = rec {
      version = "233.10527.20";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-q1IO63bI6zIzMwb2Reo5FtU+EiC9+vP8YacdavhFFmo=";
    };
    # https://www.jetbrains.com/pycharm/nextversion
    pycharm-professional = rec {
      version = "233.9802.6";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-e0W5G2i4N3ECToL5zhs+qrQKofVCbZEWJitoH2jemc8=";
    };
    # https://www.jetbrains.com/datagrip/nextversion
    datagrip = rec {
      version = "233.10527.14";
      url = "https://download.jetbrains.com/datagrip/datagrip-${version}.tar.gz";
      sha256 = "sha256-8mFfZ7zCYQGFjIWXOd/73pCM7jdeRqws4MQWyHVy8Bc=";
      plugins = ["8182-beta"];
    };
    # https://www.jetbrains.com/rust/nextversion
    rust-rover = rec {
      version = "233.8264.32";
      url = "https://download.jetbrains.com/rustrover/RustRover-${version}.tar.gz";
      sha256 = "sha256-UVD8M4WqpRi8L7lzf5Bz2kYLdtE9TAnWtMTZEr84E5s=";
      noGlobalPlugins = true;
    };
  };

  overrideFn = name: {
    version,
    url,
    sha256,
    noGlobalPlugins ? false,
    plugins ? [],
  }: let
    versionChangedPkg = jetbrains.${name}.overrideAttrs (_: _: rec {
      inherit version;
      src = pkgs.fetchurl {
        inherit url sha256;
      };
    });
    idePlugins =
      if noGlobalPlugins
      then plugins
      else plugins ++ globalPlugins;
  in
    jetbrains.plugins.addPlugins versionChangedPkg idePlugins;

  overridePkgs = builtins.mapAttrs overrideFn overrides;
in {
  jetbrains = jetbrains // overridePkgs;
}
