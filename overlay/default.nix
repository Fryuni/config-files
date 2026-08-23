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
  (import ./packages)
  (import ./patches)
  (import ./jetbrains)
  (import ./pulumi)
  (import ./rustPackages)
  (import ./vicinae-extensions.nix attrs)

  (final: pkgs: let
    inherit (pkgs.stdenv.hostPlatform) system;
  in {
    inherit (final.master) direnv;

    inherit (determinate.inputs.nix.packages.${system}) nix;
    google-workspace-cli = attrs.google-workspace-cli.packages.${system}.default;
    llm-agents = attrs.llm-agents.packages.${system};
    forgejo-cli = attrs.forgejo-cli.packages.${system}.default;

    treehouse = attrs.treehouse.packages.${system}.default.overrideAttrs (_: {doCheck = false;});
  })
]
