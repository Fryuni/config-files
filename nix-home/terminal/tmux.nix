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
    newSession = false;
    baseIndex = 1;
    clock24 = true;
    keyMode = "vi";

    extraConfig = ''
      # Switch to another session when closing the last window in the current session
      set-option -g detach-on-destroy off

      # Use vim keybindings in copy mode
      unbind -T copy-mode-vi MouseDragEnd1Pane

      # Make `y` copy the selected text, not exiting the copy mode. For copy-and-exit
      # use ordinary `Enter`
      bind -T copy-mode-vi y send-keys -X copy-pipe  # Only copy, no cancel

      # Lower escape-time, recommended by NeoVIM
      set-option -sg escape-time 10

      # Enable focus events, required by NeoVIM autoread feature
      set-option -g focus-event on

      # Enable True Color, required by termguicolors
      set-option -sa terminal-overrides ',XXX:RGB'
    '';

    tmuxp.enable = true;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      t-smart-tmux-session-manager
      fuzzback
      tmux-thumbs
      # tmux-which-key
      extrakto
    ];
  };

  home.packages = [tpkg];

  # programs.zsh.initContent = ''
  #   if [[ -z "$TMUX" ]]; then
  #     exec "${tpkg}/bin/t"
  #   fi
  # '';

  programs.fzf.tmux.enableShellIntegration = true;
}
