_: pkgs:
let
  overrides = {
    webstorm = rec {
      version = "2022.2.3";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-HX1GS7y4PVr0g1mu2mqn0WUDi/qh8m/vEBl2HrJ4+iI=";
    };
    goland = rec {
      version = "2022.2.5";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-Fk1KESLPFdsmNhZTjfXSSjMxT+gqmdmSX9PLspl6eYc=";
    };
    pycharm-professional = rec {
      version = "2022.2.4";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-zWJT9VjvCy84kHE0Ac/hHq23F8FDc9+7UgvtzmIecos=";
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
