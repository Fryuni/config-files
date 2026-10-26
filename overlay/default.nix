{determinate, ...} @ attrs: [
  attrs.fenix.overlays.default
  attrs.zig.overlays.default
  attrs.agenix.overlays.default
  attrs.nix-alien.overlays.default
  attrs.nur.overlays.default
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
    llm-agents = attrs.llm-agents.packages.${system};
    forgejo-cli = attrs.forgejo-cli.packages.${system}.default;

    treehouse = attrs.treehouse.packages.${system}.default.overrideAttrs (_: {doCheck = false;});
  })
]
