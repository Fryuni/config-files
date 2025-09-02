{pkgs, ...}: let
  tpkg = pkgs.runCommand "t" {} ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.tmuxPlugins.t-smart-tmux-session-manager}/share/tmux-plugins/*/bin/t "$out/bin/t"
  '';
in {
  programs.tmux = {
    enable = true;
    package = pkgs.master.tmux;
    terminal = "screen-256color";
    newSession = true;
    baseIndex = 1;
    clock24 = true;
    keyMode = "vi";

    extraConfig = ''
      set-option -g detach-on-destroy off
    '';

    tmuxp.enable = true;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      t-smart-tmux-session-manager
      fuzzback
      tmux-thumbs
      tmux-which-key
      extrakto
    ];
  };

  home.packages = [tpkg];

  programs.zsh.initContent = ''
    if [[ -z "$TMUX" ]]; then
      exec "${tpkg}/bin/t"
    fi
  '';

  programs.fzf.tmux.enableShellIntegration = true;
}
