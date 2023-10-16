final: pkgs: let
  inherit (pkgs.master) jetbrains;

  globalPlugins = [
    "164"
    "17718"
  ];

  overrides = {
    # https://www.jetbrains.com/webstorm/nextversion
    webstorm = rec {
      version = "2023.2.3";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-tX9KcTYaIkrrDoDy8xH2MqsXVzVqLeNiet4+ndTuCJk=";
    };
    # https://www.jetbrains.com/go/nextversion
    goland = rec {
      version = "233.9102.195";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-C73LZR1NSR8mB8YLRq1iVHvdWAJsPS1d/ygQ4MqAjN8=";
    };
    # https://www.jetbrains.com/pycharm/nextversion
    pycharm-professional = rec {
      version = "233.9802.6";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-e0W5G2i4N3ECToL5zhs+qrQKofVCbZEWJitoH2jemc8=";
    };
    # https://www.jetbrains.com/datagrip/nextversion
    datagrip = rec {
      version = "233.9102.70";
      url = "https://download.jetbrains.com/datagrip/datagrip-${version}.tar.gz";
      sha256 = "sha256-jo6+OMglpOEaGKB+pYZ6TpZGj626EhqeijRCLM/bmfg=";
      plugins = ["8182-beta"];
    };
    # https://www.jetbrains.com/rust/nextversion
    rust-rover = rec {
      version = "233.8264.22";
      url = "https://download.jetbrains.com/rustrover/RustRover-${version}.tar.gz";
      sha256 = "sha256-PdjpmwZhZO/BHobjKJ5ETFI4386OkUL+LTqMNA7usXU=";
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
    idePlugins = if noGlobalPlugins then plugins else plugins ++ globalPlugins;
  in
    jetbrains.plugins.addPlugins versionChangedPkg idePlugins;

  overridePkgs = builtins.mapAttrs overrideFn overrides;
in {
  jetbrains = jetbrains // overridePkgs;
}
