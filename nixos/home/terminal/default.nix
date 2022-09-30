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
  ];

  xdg.configFile."neofetch/config.conf".source = ../../../common/neofetch/config.conf;

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
      "refresh-gcloud-credentials" = "gcloud auth print-access-token > /dev/null";

      ns = "nix-shell --command zsh";
      nixc = "nix develop -c";
    };

    initExtra = ''
      trim() {
        local var="$*"
        # remove leading whitespace characters
        var="''${var#"''${var%%[![:space:]]*}"}"
        # remove trailing whitespace characters
        var="''${var%"''${var##*[![:space:]]}"}"
        printf '%s' "$var"
      }

      start_zellij() {
        local session_name="$1"

        if [ -z "$session_name"]; then
          gum style --faint --italic --bold "Zellij session name:"

          local session_name=$(gum input --char-limit=40)
        fi

        if [ -z "$session_name" ]; then
          exec ${pkgs.zellij}/bin/zellij
        else
          exec ${pkgs.zellij}/bin/zellij -s "$session_name"
        fi
      }

      if [ -z "$ZELLIJ" ]; then
        ongoing_sessions=$(trim "$(${pkgs.zellij}/bin/zellij ls 2>/dev/null)")

        if [ -z "$ongoing_sessions" ]; then
          start_zellij main
        else
          gum style --faint --italic --bold "Chose a session (or create a new one):"

          pick_options=$(trim "''${ongoing_sessions}\nCreate new session")
          chosen=$(echo "$pick_options" | ${pkgs.gum}/bin/gum filter)

          if [ "$chosen" = "Create new session" ]; then
            start_zellij
          else
            exec ${pkgs.zellij}/bin/zellij attach "$chosen"
          fi
        fi
      fi
    '';

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
