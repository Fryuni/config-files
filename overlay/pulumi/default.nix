final: pkgs: let
  data = import ./data.nix {};
  system = pkgs.stdenv.hostPlatform.system;
in {
  pulumi-bin = pkgs.pulumi-bin.overrideAttrs (_: _: {
    inherit (data) version;
    __intentionallyOverridingVersion = true;

    srcs = map pkgs.fetchurl data.pulumiPkgs.${system};
  });
}
