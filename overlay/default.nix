{direnv, parsecgaming, ...}: [
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
