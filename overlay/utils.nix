final: pkgs: {
  lib =
    pkgs.lib
    // (import ./lib.nix {inherit pkgs;})
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

  inherit (pkgs.stable) electron;
  inherit (pkgs.stable) electron_36;

  # NOTE: 1.5.7 is the last MPL-licensed Terraform release; later versions are BUSL.
  # The pin is terminal, so it has no update recipe. `renameWithSuffix` output has
  # no version/src attributes, which nix-update requires.
  terraformOSS = let
    package = pkgs.mkTerraform {
      version = "1.5.5";
      hash = "sha256-SBS3a/CIUdyIUJvc+rANIs+oXCQgfZut8b0517QKq64=";
      vendorHash = "sha256-lQgWNMBf+ioNxzAV7tnTQSIS840XdI9fg9duuwoK+U4=";
      passthru = {
        inherit (pkgs.terraform) plugins;
      };
    };
  in
    final.lib.renameWithSuffix package "oss";

  # nix-visualize =
  #   import (pkgs.fetchFromGitHub {
  #     owner = "craigmbooth";
  #     repo = "nix-visualize";
  #     rev = "ee6ad3cb3ea31bd0e9fa276f8c0840e9025c321a";
  #     sha256 = "sha256-nsD5U70Ue30209t4fU8iMLCHzNZo18wKFutaFp55FOw=";
  #   })
  #   {inherit pkgs;};

  grafterm = pkgs.buildGoModule {
    pname = "grafterm";
    version = "0.2.0";

    src = pkgs.fetchFromGitHub {
      owner = "slok";
      repo = "grafterm";
      rev = "v0.2.0";
      sha256 = "sha256-0pM36rAmwx/P1KAlmVaGoSj8eb9JucYycNC2R867dVo=";
    };

    vendorHash = "sha256-P5N738GXGk3S0GhIHYhkuNoyF69OX12ibL3H6c4Ki1E=";
  };

  pg-schema-diff = pkgs.buildGoModule {
    pname = "pg-schema-diff";
    version = "1.0.9-unstable-2026-08-06";
    doCheck = false;

    src = pkgs.fetchFromGitHub {
      owner = "stripe";
      repo = "pg-schema-diff";
      rev = "9ada4710c28718312557c84cca1be4b2557eed54";
      sha256 = "sha256-ycp4dM7PwuKH71Od4qqcwJ5JOJfSHv/hq4jrRYljfjM=";
    };

    vendorHash = "sha256-9tronDAe3/5bBtiMW04YGSgxww/F7xlq84sjYFTfxnk=";
  };

  wtf = pkgs.buildGoModule rec {
    pname = "wtf";
    version = "0.50.0";
    doCheck = false;

    src = pkgs.fetchFromGitHub {
      owner = "wtfutil";
      repo = "wtf";
      rev = "v${version}";
      sha256 = "sha256-sq+8r317JMY8Wbl3KlrmHgIicbs6HZ3BLtG4VGBSHM4=";
    };

    vendorHash = "sha256-lOo+ghppMA2FtKkA6xd2irPsk6ATZEydexBPOm48sy4=";
  };

  # gh = let
  #   ghWithGo126 = pkgs.gh.override {
  #     buildGoModule = pkgs.buildGo126Module;
  #   };
  # in
  #   ghWithGo126.overrideAttrs (old:
  #     assert pkgs.lib.assertMsg (pkgs.lib.versionOlder old.version "2.87.1") "gh has been updated upstream, remove this override"; {
  #       version = "2.87.1";
  #       src = pkgs.fetchFromGitHub {
  #         owner = "cli";
  #         repo = "cli";
  #         rev = "v2.87.1";
  #         hash = "sha256-omwlYkMcef33YoOkr9N1+llJqwFW2+Y9JnGe7or2JUc=";
  #       };
  #       vendorHash = "sha256-jf0PYnv6SnyI5c++o7niLgu5knUiwDq/dOvYV9EhoKg=";
  #       doCheck = false;
  #     });

  inherit (pkgs.master) bun;
}
