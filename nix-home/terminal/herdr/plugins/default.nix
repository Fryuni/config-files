{
  pkgs,
  inputs,
}: {
  herdr-treehouse = pkgs.callPackage ./herdr-treehouse.nix {
    source = inputs.herdr-treehouse;
  };
}
