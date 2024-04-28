{pkgs, ...}: {
  programs.zellij = {
    enable = true;
    package = pkgs.rustCrates.zellij;
  };

  xdg.configFile."zellij/config.kdl".text = ''
    pane_frames false
    layout_dir "${../../common/zellij/layouts}"
  '';
}
