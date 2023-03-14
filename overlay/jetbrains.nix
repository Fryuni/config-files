final: pkgs: let
  inherit (pkgs) jetbrains;

  overrides = {
    # https://www.jetbrains.com/webstorm/download/other.html
    webstorm = rec {
      version = "2022.3.3";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-V7BTb7h+hAqPcaHHl+t/drYfFqk9wGQlDgLoto/1Iag=";
    };
    # https://www.jetbrains.com/go/download/other.html
    goland = rec {
      version = "2022.3.3";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-jIW1a04iZzmg42VJ9fgP7Uy/KyeY7/RCSZ9XeTlqaRc=";
    };
    # https://www.jetbrains.com/pycharm/download/other.html
    pycharm-professional = rec {
      version = "2022.3.3";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-UMN6r9n746eNl8zPT3q9gCZsVI0cfqR1GwjFKBDxby0=";
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
