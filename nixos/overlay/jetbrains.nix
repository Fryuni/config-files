final: pkgs:
let
  overrides = {
    webstorm = rec {
      version = "2022.2.2";
      url = "https://download.jetbrains.com/webstorm/WebStorm-${version}.tar.gz";
      sha256 = "sha256-UGsl/yZM6ILHOFdwRLraTjILH1pN2XwoiHMMkfgPBx4=";
    };
    goland = rec {
      version = "2022.2.3";
      url = "https://download.jetbrains.com/go/goland-${version}.tar.gz";
      sha256 = "sha256-/aR9mTm5XYmV0aN1RDAlWZzXSxtaKWYnNHfs+vqc5PE=";
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
