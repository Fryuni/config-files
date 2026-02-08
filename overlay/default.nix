{
  nixpkgs,
  parsecgaming,
  determinate,
  ...
} @ attrs: let
  pickPackages = f: pick: final: pkgs: nixpkgs.lib.filterAttrs (name: _: builtins.elem name pick) (f final pkgs);
in [
  attrs.fenix.overlays.default
  attrs.zig.overlays.default
  attrs.agenix.overlays.default
  attrs.nix-alien.overlays.default
  attrs.nur.overlays.default
  attrs.llm-agents.overlays.default
  (pickPackages attrs.flakehub.overlays.default ["fh"])
  attrs.polymc.overlay

  (import ./utils.nix)
  (import ./patches.nix)
  (import ./jetbrains.nix)
  (import ./croct.nix)
  (import ./pulumi)
  (import ./rustPackages)
  (final: pkgs: {
    oh-my-opencode = pkgs.callPackage ./oh-my-opencode.nix {};
  })
  (final: pkgs: let
    inherit (pkgs.stdenv.hostPlatform) system;
  in {
    inherit (final.master) direnv;
    # direnv = direnv.packages.${system}.default;
    inherit (parsecgaming.packages.${system}) parsecgaming;

    inherit (determinate.inputs.nix.packages.${system}) nix;
  })
]
