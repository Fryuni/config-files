{pkgs, ...}: {
  imports = [
    ./cli.nix
    ./neovim.nix
    ./alacritty.nix
    ./ghostty.nix
    ./tmux.nix
  ];

  home.packages = with pkgs; [
    pfetch
    neofetch
  ];

  xdg.configFile."neofetch/config.conf".source = ../../common/neofetch/config.conf;

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };
  xdg.configFile."starship.toml".source = ../../common/rcfiles/starship.toml;

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;

    config = {
      global = {
        load_dotenv = true;
      };
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    autocd = true;

    initContent = pkgs.lib.mkBefore ''
      setopt cdable_vars
    '';
    # if [ -z "$ZELLIJ" ] && [ -z "$TERMINAL_EMULATOR" ]; then
    #   exec zellij
    # fi

    dirHashes = {
      nix-system = "/run/current-system";
      nix-boot = "/nix/var/nix/profiles/system";
      nix-hm = "/nix/var/nix/profiles/per-user/$USER/home-manager";

      syscfg = "$HOME/ZShutils";
      oss = "$HOME/IsoWorkspaces/OSS";
      reviews = "$HOME/IsoWorkspaces/reviews";

      ct = "$HOME/IsoWorkspaces/Croct";
      ct-meta = "$HOME/IsoWorkspaces/Croct/metas";
      ct-infra = "$HOME/IsoWorkspaces/Croct/infra";
      ct-tf = "$HOME/IsoWorkspaces/Croct/infra/terraformation";

      nvc = "$HOME/.config/nvim";
    };

    shellAliases = {
      ls = "ls --color=auto";
      ll = "eza -bghHliS --git";
      la = "eza -bghHliSa --git";
      lg = "lazygit";

      nv = "nvim";
      nivm = "nvim";

      "refresh-gcloud-credentials" = "gcloud auth print-access-token > /dev/null";
      gselect = "gcloud config configurations activate";

      # Run code inside of a container with the full home context
      drun = "docker run -it --rm -v /run/user/$UID:/run/user/$UID -v /home/lotus:/home/lotus -w $(pwd) -u $UID:$GID -e HOME=$HOME";

      ns = "nix shell";
      nixc = "nix develop -c";
      tmp = "cd $(mktemp -d)";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        # "dotenv"
        "gcloud"
        "docker"
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
