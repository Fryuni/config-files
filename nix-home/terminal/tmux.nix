{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    package = pkgs.master.tmux;
    terminal = "screen-256color";
    newSession = true;
    clock24 = true;
    keyMode = "vi";

    plugins = with pkgs.tmuxPlugins; [
      session-wizard
    ];
  };
}
