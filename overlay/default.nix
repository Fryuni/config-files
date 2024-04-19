{direnv, ...}: [
  (import ./utils.nix)
  (import ./jetbrains.nix)
  (import ./croct.nix)
  (import ./pulumi)
  (import ./rustPackages)
  (final: pkgs: {
    direnv = direnv.packages.${pkgs.system}.default;
  })
]
