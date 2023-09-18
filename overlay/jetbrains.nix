final: pkgs: let
  inherit (pkgs) jetbrains;

  overrides = {
    # https://www.jetbrains.com/webstorm/nextversion
    webstorm = rec {
      version = "2023.2.2";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-EMEgNiAli/SwyVLYCfUOqVT4DR7WAJiRekxk+ycYuTE=";
    };
    # https://www.jetbrains.com/go/nextversion
    goland = rec {
      version = "2023.2.2";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-4pUd/NgFVvKTeNVcjU6/vG5ZnhStoXoGOGcpIh1xNTs=";
    };
    # https://www.jetbrains.com/pycharm/nextversion
    pycharm-professional = rec {
      version = "232.9921.36";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-VY6t1Zl05dIEng1SZo2kffywRcO+lTRGJXcuqYX54hQ=";
    };
    # https://www.jetbrains.com/datagrip/nextversion
    datagrip = rec {
      version = "2023.2.1";
      url = "https://download.jetbrains.com/datagrip/datagrip-${version}.tar.gz";
      sha256 = "sha256-CyDw3GHY/ZtCli1JMcZHQt0X4/AI3+wsiGOlaxvEvps=";
    };
  };

  overrideFn = name: {
    version,
    url,
    sha256,
  }:
    jetbrains.${name}.overrideAttrs (_: _: rec {
      inherit version;
      src = pkgs.fetchurl {
        inherit url sha256;
      };
    });

  overridePkgs = builtins.mapAttrs overrideFn overrides;
in {
  jetbrains = jetbrains // overridePkgs;
}
