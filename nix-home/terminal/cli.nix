{
  pkgs,
  config,
  ...
}: let
  gcloud-sdk = (pkgs.stable.google-cloud-sdk.override {python312 = pkgs.stable.python310;}).withExtraComponents (
    with pkgs.stable.google-cloud-sdk.components; [
      docker-credential-gcr
      beta
      alpha
      gsutil
      gke-gcloud-auth-plugin
      # terraform-tools
    ]
  );
in {
  home.packages = with pkgs; [
    # Nix
    nix-prefetch
    nix-visualize
    nix-tree
    master.nix-search

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
    jqp
    gojq

    # Charm.sh pretty binaries
    nur.repos.charmbracelet.gum
    nur.repos.charmbracelet.charm
    nur.repos.charmbracelet.glow
    nur.repos.charmbracelet.skate

    # Cloud
    terraform
    tfk8s
    pulumi-bin
    gcloud-sdk
    google-cloud-sql-proxy

    # AI
    master.opencode
    nur.repos.charmbracelet.crush
    (symlinkJoin {
      name = "mods-authenticated";
      nativeBuildInputs = [makeWrapper coreutils];
      paths = [nur.repos.charmbracelet.mods];
      postBuild = ''
        for file in ${nur.repos.charmbracelet.mods}/bin/*; do
          rm -rf "$out/bin/$(basename $file)"
          makeWrapper $file "$out/bin/$(basename $file)" \
            --run 'export OPENAI_API_KEY="$(cat ${config.age.secrets.openai-key.path})"'
        done
      '';
    })

    grafterm
    python312Packages.habitipy
    yt-dlp
  ];

  programs.zsh.shellAliases = {
    clear-mods-conversations = "rm -rf ~/.local/share/mods/conversations";
    oc = "opencode";
  };

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
