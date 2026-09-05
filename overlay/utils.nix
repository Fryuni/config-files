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

  bun = pkgs.master.bun.overrideAttrs (
    finalAttrs: prevAttrs:
      assert pkgs.lib.assertMsg (pkgs.lib.versionOlder prevAttrs.version "1.4.0") "bun has been updated upstream, remove this override"; {
        version = "1.4.1";
        __intentionallyOverridingVersion = true;
        passthru =
          prevAttrs
          // {
            sources = {
              "aarch64-darwin" = pkgs.fetchurl {
                url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-darwin-aarch64.zip";
                hash = "sha256-2Jc86DX6eGflzHmv7m/G8a4BF6pL1fwlRv0AxRL3E4Y=";
              };
              "aarch64-linux" = pkgs.fetchurl {
                url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-linux-aarch64.zip";
                hash = "sha256-WAzndTMQjcaxC+wXITl+T1qkTpCXJtokUdSD38XlgdY=";
              };
              "x86_64-linux" = pkgs.fetchurl {
                url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-linux-x64-baseline.zip";
                hash = "sha256-qMnGc4IC4vztVV3YYKlTxWwM0Fn3UEHnAQroGjKAJkY=";
              };
            };
          };
      }
  );
}
