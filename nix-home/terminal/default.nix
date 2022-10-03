{ pkgs, ... }:
{
  imports = [
    ./cli.nix
    ./doom-nvim.nix
    ./alacritty.nix
  ];

  home.packages = with pkgs; [
    pfetch
    neofetch
  ];

  xdg.configFile."neofetch/config.conf".source = ../../common/neofetch/config.conf;

  programs.zellij = {
    enable = true;
    package = pkgs.zellij;
    settings = {
      pane_frames = false;
    };
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };
  xdg.configFile."starship.toml".source = ../../common/rcfiles/starship.toml;

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
