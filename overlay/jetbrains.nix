final: pkgs: let
  inherit (pkgs) jetbrains;

  overrides = {
    # https://www.jetbrains.com/webstorm/download/other.html
    webstorm = rec {
      version = "232.8660.7";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-HfmoQxnV1qJQkrohl7AqVwqGjA4ji5OG4b6OlTPSePs=";
    };
    # https://www.jetbrains.com/go/download/other.html
    goland = rec {
      version = "232.8660.55";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-tmMC32pEhG0T446ZEWPQLm3+ULLXeR13pssJue1frUw=";
    };
    # https://www.jetbrains.com/pycharm/download/other.html
    pycharm-professional = rec {
      version = "232.8660.49";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-XWWgb/JT+A75BNpioPXMMEso8NVhnmWNQXyYfgEH0wY=";
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
