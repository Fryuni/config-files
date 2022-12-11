{pkgs, ...}: {
  home.packages = with pkgs; [
    wezterm
  ];

  xdg.configFile."wezterm/wezterm.lua".text = ''
    local wezterm = require 'wezterm'

    return {
      font = wezterm.font 'JetBrainsMono Nerd Font',
      font_size = 16,
      color_scheme = 'Chalk', -- 候補: Chester, Chalk, Ayu Mirage など
      window_background_opacity = 0.85,
      hide_tab_bar_if_only_one_tab = false,

      backgrounds = {
        { Color = 'black' },
        {
          source = { File = '${../../common/wallpaper/wallpaper.png}' },

          repeat_x = 'NoRepeat',
          repeat_y = 'NoRepeat',

          vertical_align = 'Middle',
          horizontal_align = 'Center',

          height = 'Cover',
          width = 'Cover',

          hsb = {
            brightness = 0.1,
            saturation = 0.8,
          },
        },
      },

      default_prog = { 'zellij' },
      launch_menu = {
        {
          label = 'Zellij New',
          args = { 'zellij' },
        },
        {
          label = 'Zellij Attach',
          args = { 'zellij', 'attach' },
        },
      },
    }
  '';
}
