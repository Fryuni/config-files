{
  pkgs,
  config,
  ...
}: {
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    installVimSyntax = true;
    settings = {
      font-family = "JetBrainsMono Nerd Font";
      mouse-hide-while-typing = true;
      fullscreen = true;
      auto-update = "off";
    };
  };
}
