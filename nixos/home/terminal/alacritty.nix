{ pkgs, ... }:
{
  programs.alacritty.enable = true;
  programs.alacritty.settings = {
    env.TERM = "screen-256color";

    shell = {
      program = "${pkgs.zellij}/bin/zellij";
    };

    window = {
      dimensions.columns = 0;
      dimensions.lines = 0;

      padding.x = 2;
      paddind.y = 2;

      decorations = "full";
      dynamic_title = true;
    };

    draw_bold_text_with_bright_colors = true;

    font =
      let
        family = "JetBrainsMono Nerd Font";
      in
      {
        normal = {
          inherit family;
          style = "Regular";
        };
        bold = {
          inherit family;
          style = "Bold";
        };
        italic = {
          inherit family;
          style = "Italic";
        };
      };
  };
}
