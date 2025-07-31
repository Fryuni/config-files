{
  pkgs,
  config,
  ...
}: let
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
    nix-prefetch
    nix-visualize
    nix-tree

    # Utils
    coreutils
    (symlinkJoin {
      name = "moreutils-wrapped";
      paths = [moreutils];
      nativeBuildInputs = [fd];
      postBuild = ''
        fd parallel $out -X rm
      '';
    })
    binutils
    pciutils
    parallel
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
    eza
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
    (symlinkJoin {
      name = "mods-authenticated";
      nativeBuildInputs = [makeWrapper coreutils];
      paths = [mods];
      postBuild = ''
        for file in ${mods}/bin/*; do
          rm -rf "$out/bin/$(basename $file)"
          makeWrapper $file "$out/bin/$(basename $file)" \
            --run 'export OPENAI_API_KEY="$(cat ${config.age.secrets.openai-key.path})"'
        done
      '';
    })

    # Cloud
    terraform
    tfk8s
    pulumi-bin
    gcloud-sdk
    google-cloud-sql-proxy

    grafterm
    python312Packages.habitipy
    yt-dlp
  ];

  programs.zsh.shellAliases."clear-mods-conversations" = "rm -rf ~/.local/share/mods/conversations";

  home.sessionVariables = {
    USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
  };

  programs.jq.enable = true;
  programs.pgcli.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  home.file.".cargo/cargo.toml".source = ../../common/rcfiles/cargo.toml;
  home.file.".cargo/config.toml".source = ../../common/rcfiles/cargo-config.toml;
}
