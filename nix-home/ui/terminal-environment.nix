{pkgs, ...}: let
  desktopEnvironment = pkgs.writeShellApplication {
    name = "local-desktop-environment";
    runtimeInputs = with pkgs; [coreutils jq systemd];
    text = builtins.readFile ../../common/scripts/local-desktop-environment.sh;
  };
in {
  # Home Manager already imports DISPLAY and XAUTHORITY at graphical login.
  xsession.importedVariables = [
    "XDG_CURRENT_DESKTOP"
    "XDG_SESSION_DESKTOP"
    "XDG_SESSION_TYPE"
  ];

  # .zshenv also runs for noninteractive SSH commands and new multiplexer panes.
  # Refresh on every shell, even if hm-session-vars.sh was sourced by its parent.
  programs.zsh.envExtra = ''
    eval "$(${pkgs.lib.getExe desktopEnvironment} 2>/dev/null || true)"
  '';
}
