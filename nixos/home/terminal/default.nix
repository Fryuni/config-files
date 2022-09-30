{ pkgs, ... }:
{
  imports = [
    ./cli.nix
    ./neovim.nix
    ./alacritty.nix
  ];

  home.packages = with pkgs; [
    pfetch
    neofetch
    zellij
  ];

  xdg.configFile."neofetch/config.conf".source = ../../../common/neofetch/config.conf;

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };
  xdg.configFile."starship.toml".source = ../../../common/rcfiles/starship.toml;

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    autocd = true;

    dirHashes = {
      nix-system = "/run/current-system";
      nix-boot = "/nix/var/nix/profiles/system";
      nix-hm = "/nix/var/nix/profiles/per-user/$USER/home-manager";
    };

    shellAliases = {
      ls = "ls --color=auto";
      ll = "exa -bghHliS --git";
      la = "exa -bghHliSa --git";
      tmux = "tmux -2";
      "refresh-gcloud-credentials" = "gcloud auth print-access-token > /dev/null";

      ns = "nix-shell --command zsh";
      nixc = "nix develop -c";
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
