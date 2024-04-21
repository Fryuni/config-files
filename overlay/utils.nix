final: pkgs: {
  lib =
    pkgs.lib
    // {
      maintainers =
        pkgs.lib.maintainers
        // {
          fryuni = {
            name = "Luiz Ferraz";
            github = "Fryuni";
            gitlab = "Fryuni";
            email = "luiz@lferraz.com";
          };
        };
    };

  python311Packages =
    pkgs.python311Packages
    // {
      inherit (pkgs.stable.python311Packages) pyqt6-webengine;
    };

  stremio = pkgs.stremio.override {
    inherit (pkgs.stable) qtwebchannel;
    inherit (pkgs.stable.qt5) qmake qtwebengine wrapQtAppsHook;
  };

  # ksp-ckan = pkgs.callPackage ./ckan.nix {};

  # neovim = pkgs.stable.neovim;
  # neovim-unwrapped = pkgs.stable.neovim-unwrapped;
  # wrapNeovimUnstable = pkgs.stable.wrapNeovimUnstable;

  # nix-visualize =
  #   import (pkgs.fetchFromGitHub {
  #     owner = "craigmbooth";
  #     repo = "nix-visualize";
  #     rev = "ee6ad3cb3ea31bd0e9fa276f8c0840e9025c321a";
  #     sha256 = "sha256-nsD5U70Ue30209t4fU8iMLCHzNZo18wKFutaFp55FOw=";
  #   })
  #   {inherit pkgs;};

  grafterm = pkgs.buildGoModule rec {
    pname = "grafterm";
    version = "0.2.0";

    src = pkgs.fetchFromGitHub {
      owner = "slok";
      repo = "grafterm";
      rev = "v0.2.0";
      sha256 = "sha256-0pM36rAmwx/P1KAlmVaGoSj8eb9JucYycNC2R867dVo=";
    };

    vendorHash = "sha256-veg5B68AQhkSZg8YA/e4FbqJNG0YGwnUQFsAdscz0QI=";
  };

  pg-schema-diff = pkgs.buildGoModule rec {
    name = "pg-schema-diff";
    doCheck = false;

    src = pkgs.fetchFromGitHub {
      owner = "stripe";
      repo = "pg-schema-diff";
      rev = "7741e0941c20625d8f8efd0b9dabbe18faee8bca";
      sha256 = "sha256-JVW2ML+2a9tRXRue0aPXRaPq8vNsgLP0NB7J0g1uMFw=";
    };

    vendorHash = "sha256-/pzW7zK7pPo205oio4QcnOXgP7imRQ8VCdt652YCJkg=";
  };

  wtf = pkgs.buildGoModule rec {
    pname = "wtf";
    version = "0.43.0";
    doCheck = false;

    src = pkgs.fetchFromGitHub {
      owner = "wtfutil";
      repo = "wtf";
      rev = "v${version}";
      sha256 = "sha256-DFrA4bx+wSOxmt1CVA1oNiYVmcWeW6wpfR5F1tnhyDY=";
    };

    vendorHash = "sha256-f82ibPnauUOuZ5D6Rz3Yyt0jiAXvjN8Or3gud+ri6FA=";
  };

  # Use fix from https://github.com/NixOS/nixpkgs/pull/252058
  xorg =
    pkgs.xorg
    // {
      xrandr = pkgs.master.xorg.xrandr;
    };

  bun = pkgs.master.bun.overrideAttrs rec {
    version = "1.0.2";

    src = pkgs.fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64.zip";
      hash = "sha256-kHv8PU48Le4lG3pf304hXggAtx/I5uBeu4aHmLsbdgw=";
    };
  };

  ulauncher = pkgs.master.ulauncher.overridePythonAttrs {
    propagatedBuildInputs =
      pkgs.ulauncher.propagatedBuildInputs
      ++ (with pkgs.python3Packages; [
        pint
        simpleeval
        parsedatetime
        pytz
        babel
      ]);
  };
}
