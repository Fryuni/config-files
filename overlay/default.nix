{
  nixpkgs,
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
  (pickPackages attrs.flakehub.overlays.default ["fh"])
  attrs.polymc.overlay
  attrs.tmux-treehouse.overlays.default

  (import ./utils.nix)
  (import ./patches)
  (import ./jetbrains)
  (import ./pulumi)
  (import ./honcho.nix)
  (import ./rustPackages)
  (import ./vicinae-extensions.nix attrs)

  (final: pkgs: let
    inherit (pkgs.stdenv.hostPlatform) system;
  in {
    inherit (final.master) direnv;

    inherit (determinate.inputs.nix.packages.${system}) nix;
    google-workspace-cli = attrs.google-workspace-cli.packages.${system}.default;
    llm-agents = attrs.llm-agents.packages.${system};
    treehouse = attrs.treehouse.packages.${system}.default;
    forgejo-cli = attrs.forgejo-cli.packages.${system}.default;

    cpa-manager-plus = final.callPackage ./packages/cpa-manager-plus.nix {};
    openwhispr = final.callPackage ./packages/openwhispr.nix {};
  })
]
