{
  direnv,
  nix-darwin,
  ...
}: [
  (import ./utils.nix)
  (import ./jetbrains.nix)
  (import ./croct.nix)
  (import ./pulumi)
  (import ./rustPackages)
  (final: pkgs: {
    direnv = direnv.packages.${pkgs.system}.default;
    nix-darwin = nix-darwin.packages.${pkgs.system}.default;
  })
]
