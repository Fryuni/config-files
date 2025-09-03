{
  nixpkgs,
  parsecgaming,
  ...
} @ attrs: let
  pickPackages = f: pick: final: pkgs: nixpkgs.lib.filterAttrs (name: _: builtins.elem name pick) (f final pkgs);
in [
  attrs.fenix.overlays.default
  attrs.zig.overlays.default
  attrs.agenix.overlays.default
  attrs.nix-alien.overlays.default
  attrs.nur.overlays.default
  (pickPackages attrs.flakehub.overlays.default ["fh"])
  attrs.polymc.overlay

  (import ./utils.nix)
  (import ./patches.nix)
  (import ./jetbrains.nix)
  (import ./croct.nix)
  (import ./pulumi)
  (import ./rustPackages)
  (final: pkgs: {
    direnv = final.master.direnv;
    # direnv = direnv.packages.${pkgs.system}.default;
    parsecgaming = parsecgaming.packages.${pkgs.system}.parsecgaming;
  })
]
