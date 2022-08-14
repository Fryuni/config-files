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
    jq
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
  ];

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
