{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Nix
    rnix-lsp
    nixpkgs-fmt
    nix-prefetch-git
    nix-prefetch-github

    # Utils
    coreutils
    binutils
    pciutils
    gnused
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
    bat
    exa
    ripgrep
    fd
    dua
    gum

    # Git stuff
    gh
    lazygit

    # Cloud
    google-cloud-sdk
    terraform
  ];

  programs.jq.enable = true;
  programs.command-not-found.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  home.file.".cargo/cargo.toml".source = ../../common/rcfiles/cargo.toml;
  home.file.".cargo/config.toml".source = ../../common/rcfiles/cargo-config.toml;
}
