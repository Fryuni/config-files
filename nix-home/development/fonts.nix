{pkgs, ...}: {
  fonts.fontconfig.enable = true;
  home.packages = with pkgs.stable; [
    (nerdfonts.override {
      fonts = [
        "FiraCode"
        "FiraMono"
        "JetBrainsMono"
      ];
    })
  ];
}
