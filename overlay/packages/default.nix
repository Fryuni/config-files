# Registry-driven exposure for ordinary custom packages.
#
# Every registry entry (../registry.nix) with a `package` path is exposed here
# via callPackage. Entries without `package` are exposed by their own overlay
# module and must not be duplicated here.
final: pkgs: let
  registry = import ../registry.nix;
in
  builtins.listToAttrs (
    builtins.map
    (
      name: {
        inherit name;
        value = final.callPackage registry.${name}.package {};
      }
    )
    (
      builtins.filter
      (name: registry.${name} ? package)
      (builtins.attrNames registry)
    )
  )
