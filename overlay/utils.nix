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

  terraform = pkgs.mkTerraform {
    version = "1.5.5";
    hash = "sha256-SBS3a/CIUdyIUJvc+rANIs+oXCQgfZut8b0517QKq64=";
    vendorHash = "sha256-lQgWNMBf+ioNxzAV7tnTQSIS840XdI9fg9duuwoK+U4=";
    passthru = {
      inherit (pkgs.terraform) plugins;
    };
  };

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

  bun = pkgs.master.bun;

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
