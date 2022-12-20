{pkgs, ...}: let
  gcloud-sdk = pkgs.google-cloud-sdk.withExtraComponents (
    with pkgs.google-cloud-sdk.components; [
      docker-credential-gcr
      beta
      alpha
      gsutil
      gke-gcloud-auth-plugin
      terraform-tools
    ]
  );
in {
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
    stable.httpie
    yq-go
    bat
    exa
    ripgrep
    fd
    sd
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
    terraform
    pulumi-bin
    gcloud-sdk

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
