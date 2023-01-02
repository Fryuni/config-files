final: pkgs:
let
  inherit (pkgs) jetbrains;

  overrides = {
    # https://www.jetbrains.com/webstorm/download/other.html
    webstorm = rec {
      version = "2022.3.1";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-14vWSUzO1R/nfYfAcED6Oinor5FzFzmQNq8WHFav2Sc=";
    };
    # https://www.jetbrains.com/go/download/other.html
    goland = rec {
      version = "2022.2.5";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-Fk1KESLPFdsmNhZTjfXSSjMxT+gqmdmSX9PLspl6eYc=";
    };
    # https://www.jetbrains.com/pycharm/download/other.html
    pycharm-professional = rec {
      version = "2022.3.1";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-j4RQd8wPo1gjSO49dqaf8AE5Gz89Y6myebgDn9bgdiI=";
    };
  };
in {
  jetbrains =
    jetbrains
    // builtins.mapAttrs
    (name: {
      version,
      url,
      sha256,
    }:
      jetbrains.${name}.overrideAttrs (_: _: rec {
        inherit version;
        src = pkgs.fetchurl {
          inherit url sha256;
        };
      }))
    overrides;
}
