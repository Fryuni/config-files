{pkgs, ...}: {
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
  };

  xdg.configFile."zellij/config.kdl".text = ''
    pane_frames false
    layout_dir "${../../common/zellij/layouts}"
  '';

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

      syscfg = "$HOME/ZShutils";
      oss = "$HOME/IsoWorkspaces/OSS";

      croct-meta = "$HOME/IsoWorkspaces/Croct/metas";
    };

    shellAliases = {
      ls = "ls --color=auto";
      ll = "exa -bghHliS --git";
      la = "exa -bghHliSa --git";
      lg = "lazygit";
      "refresh-gcloud-credentials" = "gcloud auth print-access-token > /dev/null";

      # Run code inside of a container with the full home context
      drun = "docker run -it --rm -v /home/lotus:/home/lotus -w $(pwd) -u $(id -u):$(id -g) -e HOME=$HOME";

      ns = "nix-shell --command zsh";
      nixc = "nix develop -c";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "dotenv"
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
