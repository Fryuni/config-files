{pkgs, ...}: {
  imports = [
   ./rofi-power-menu.nix
  ];
  home.file.".local/share/rofi/themes/styles".source = ../../common/rofi/styles;
  programs.rofi = {
    enable = true;
    pass.enable = true;

    terminal = "${pkgs.ghostty}/bin/ghostty";
    theme = ../../common/rofi/sp.theme.rasi;

    plugins = with pkgs; [
      rofi-calc
      rofi-emoji
      rofi-systemd
      rofi-menugen
      rofi-power-menu
    ];

    extraConfig = {
      modi = "drun,emoji,run,keys,filebrowser";
    };
  };
}
