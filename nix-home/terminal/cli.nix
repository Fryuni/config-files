{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Nix
    nixpkgs-fmt
    nix-prefetch-git
    nix-prefetch-github
    nix-visualize

    # Utils
    coreutils
    moreutils
    binutils
    pciutils
    jo
    curl
    wget
    xsel
    xclip
    xdotool
    unzip
    figlet
    protobuf
    httpie
    yq-go
    bat
    exa
    ripgrep
    fd
    xplr
    dua

    # Charm.sh pretty binaries
    gum
    charm
    glow
    skate

    # Git stuff
    gh
    lazygit

    # Cloud
    google-cloud-sdk
    terraform

    grafterm
  ];

  programs.jq.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  home.file.".cargo/cargo.toml".source = ../../common/rcfiles/cargo.toml;
  home.file.".cargo/config.toml".source = ../../common/rcfiles/cargo-config.toml;

  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
}