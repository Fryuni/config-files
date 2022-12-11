final: pkgs: let
  data = import ./data.nix {};
in {
  pulumi-bin = pkgs.pulumi-bin.overrideAttrs (_: _: {
    inherit (data) version;

    srcs = map pkgs.fetchurl data.pulumiPkgs.${pkgs.system};
  });
}
