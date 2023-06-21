final: pkgs: let
  inherit (pkgs) jetbrains;

  overrides = {
    # https://www.jetbrains.com/webstorm/download/other.html
    webstorm = rec {
      version = "2023.1.3";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-HO8YptgOBjtSDdjpoM9bJ6nLBbv6W2gOl8VKfLQ1ycY=";
    };
    # https://www.jetbrains.com/go/download/other.html
    goland = rec {
      version = "2023.1.3";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-9FYCThtd5AWtqb1XBIP/yhEm7eycgb+gKwd/gUNLVxk=";
    };
    # https://www.jetbrains.com/pycharm/download/other.html
    pycharm-professional = rec {
      version = "2023.1.3";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-TN+FwBhU1/dMn6nv2mdFM1bxEg5JzFrtEWjw8y2O4BY=";
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
