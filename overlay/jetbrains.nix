final: pkgs: let
  inherit (pkgs) jetbrains;

  overrides = {
    # https://www.jetbrains.com/webstorm/download/other.html
    webstorm = rec {
      version = "2023.2";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-zJfIukRWDepB3hwD/WAjoofD3KZHbCl/AqRzrxJMBz8=";
    };
    # https://www.jetbrains.com/go/download/other.html
    goland = rec {
      version = "2023.2";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-F/G72aRgYf3QE9SamYWcHKPs4aPMUc3PK0bq4EMvJIE=";
    };
    # https://www.jetbrains.com/pycharm/download/other.html
    pycharm-professional = rec {
      version = "2023.2";
      url = "https://download.jetbrains.com/python/pycharm-professional-${version}.tar.gz";
      sha256 = "sha256-lfFmbEcanXUsU+wLd2hAVS4CP2QFo7AAzm8QFBJb/IM=";
    };
    # https://www.jetbrains.com/datagrip/download/other.html
    datagrip = rec {
      version = "2023.2";
      url = "https://download.jetbrains.com/datagrip/datagrip-${version}.tar.gz";
      sha256 = "sha256-+DRNrU9QKiFUQPt8y8TGms3QsY8z2FXw0NDSu+RKXyY=";
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
