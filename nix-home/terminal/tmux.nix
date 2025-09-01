{pkgs, ...}: {
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
      session-wizard
    ];
  };

  programs.zsh.initContent = ''
    if [[ -z "$TMUX" ]]; then
      set -euo pipefail
      cd "$HOME"
      TMUX_TARGET=$(echo "$HOME/$(fd -HI -td -d 4 -E 'node_modules' . . | fzf)" || echo "$HOME")
      exec "${pkgs.tmuxPlugins.session-wizard}/share/tmux-plugins/session-wizard/bin/t" "$TMUX_TARGET"
    fi
  '';

  programs.fzf.tmux.enableShellIntegration = true;
}
