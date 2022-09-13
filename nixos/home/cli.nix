{ pkgs, ... }:
let
  nix-visualize = import
    (pkgs.fetchFromGitHub {
      owner = "craigmbooth";
      repo = "nix-visualize";
      rev = "ee6ad3cb3ea31bd0e9fa276f8c0840e9025c321a";
      sha256 = "sha256-nsD5U70Ue30209t4fU8iMLCHzNZo18wKFutaFp55FOw=";
    })
    { inherit pkgs; };
in
{
  home.packages = with pkgs; [
    # Nix
    rnix-lsp
    nixpkgs-fmt
    nix-prefetch-git
    nix-prefetch-github
    #nix-visualize

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
