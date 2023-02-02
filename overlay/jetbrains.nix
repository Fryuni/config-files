final: pkgs: let
  inherit (pkgs) jetbrains;

  overrides = {
    # https://www.jetbrains.com/webstorm/download/other.html
    webstorm = rec {
      version = "2022.3.2";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-K2Ehd8mf8MbFQqvgBYRsOqbPFw+qAgLar+tKsWJ8N5Q=";
    };
    # https://www.jetbrains.com/go/download/other.html
    goland = rec {
      version = "2022.3.2";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-8TDQ5MLInc0pHgXMozSE6wjiR+nsKcE96vZxdq+/ajY=";
    };
    # https://www.jetbrains.com/pycharm/download/other.html
    pycharm-professional = rec {
      version = "2022.3.2";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-VkMAkN1HHhBv3EhGMCfYneYkdZ+HVySM7Zd2l4hU5PY=";
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
