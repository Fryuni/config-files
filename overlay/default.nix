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
  (final: pkgs: {
    tmuxPlugins =
      pkgs.tmuxPlugins
      // {
        treehouse = attrs.tmux-treehouse.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs (finalAttrs: old: {
          pname = "tmuxplugin-treehouse";
          passthru =
            (old.passthru or {})
            // {rtp = "${finalAttrs.finalPackage}/share/tmux-plugins/tmux-treehouse";};
        });
      };
  })

  (import ./utils.nix)
  (import ./patches.nix)
  (import ./jetbrains.nix)
  (import ./croct.nix)
  (import ./pulumi)
  (import ./agentfs.nix)
  (import ./openwhispr.nix)
  (import ./honcho.nix)
  (import ./rustPackages)
  (final: pkgs: let
    inherit (pkgs.stdenv.hostPlatform) system;
  in {
    inherit (final.master) direnv;

    inherit (determinate.inputs.nix.packages.${system}) nix;
    google-workspace-cli = attrs.google-workspace-cli.packages.${system}.default;
    llm-agents = attrs.llm-agents.packages.${system};
    treehouse = attrs.treehouse.packages.${system}.default;
    forgejo-cli = attrs.forgejo-cli.packages.${system}.default;
  })
]
