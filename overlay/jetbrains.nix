_: pkgs:
let
  overrides = {
    # https://www.jetbrains.com/webstorm/download/other.html
    webstorm = rec {
      version = "2022.3";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-pwogdPg4xKX1C5nYeXN2vz9XzbQOnHKCRlVfm0rF01s=";
    };
    # https://www.jetbrains.com/go/download/other.html
    goland = rec {
      version = "2022.2.5";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-Fk1KESLPFdsmNhZTjfXSSjMxT+gqmdmSX9PLspl6eYc=";
    };
    # https://www.jetbrains.com/pycharm/download/other.html
    pycharm-professional = rec {
      version = "2022.3";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-WhLHxpm3yrLoG8L4NCXBQe85Y4EQA5XalPqgZM/Zxc0=";
    };
  };
in
{
  jetbrains = pkgs.jetbrains
    // builtins.mapAttrs
    (name: { version, url, sha256 }:
      pkgs.jetbrains.${name}.overrideAttrs (_: _: rec {
        inherit version;
        src = pkgs.fetchurl {
          inherit url sha256;
        };
      }))
    overrides;
}
