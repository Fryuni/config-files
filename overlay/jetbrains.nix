final: pkgs: let
  inherit (pkgs) jetbrains;

  overrides = {
    # https://www.jetbrains.com/webstorm/download/other.html
    webstorm = rec {
      version = "2023.1";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-vQdMe6/c/M5NsAGkNWBA0LrdfNL2VBijW0FWsAoH6Us=";
    };
    # https://www.jetbrains.com/go/download/other.html
    goland = rec {
      version = "2023.1";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-8gjiRx71xOIy/0lDTowUzmFLeSSWPr0o1MhjOZ3ULSw=";
    };
    # https://www.jetbrains.com/pycharm/download/other.html
    pycharm-professional = rec {
      version = "2023.1";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-JsP0mtiZF4EFlD62Phq66FxA8vRDYqKyBimmJjpPjaY=";
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
