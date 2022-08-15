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
  programs.alacritty.settings = {
    env.TERM = "screen-256color";

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
        family = "FiraMono Nerd Font";
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

  programs.tmux = {
    enable = true;
  };

  # environment.pathsToLink = [ "/share/zsh" ];

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    autocd = true;

    shellAliases = {
      ls = "ls --color=auto";
      ll = "exa -bghHliS --git";
      la = "exa -bghHliSa --git";
      tmux = "tmux -2";
      "refresh-gcloud-credentials" = "gcloud auth print-access-token > /dev/null";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "gcloud"
        "docker"
        "nvm"
        "node"
        "npm"
        "yarn"
        "rust"
        "command-not-found"
        "sudo"
        "systemd"
        "terraform"
        "encode64"
        "httpie"
      ];
    };
  };
}
