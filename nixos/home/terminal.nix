{ pkgs, ... }:
{
  home.packages = with pkgs; [
    neofetch
  ];

  xdg.configFile."neofetch/config.conf".source = ../../common/neofetch/config.conf;

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };
  xdg.configFile."starship.toml".source = ../../common/rcfiles/starship.toml;

  programs.alacritty.enable = true;
  programs.alacritty.settigns = ''
    env:
      TERM: screen-256color

    window:
      dimensions:
        columns: 0
        lines: 0
      padding:
        x: 2
        y: 2
      decorations: full
      dynamic_title: true

    draw_bold_text_with_bright_colors: true

    font:
      normal:
        family: &terminalFont 'FiraMono Nerd Font'
        style: Regular

      bold:
        family: *terminalFont
        style: Bold

      italic:
        family: *terminalFont
        style: Italic
  '';
}
