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
  withOpenAi = pkg:
    pkg.overrideAttrs (prev: {
      buildInputs = (prev.buildInputs or []) ++ [pkgs.makeWrapper];
      postFixup = ''
        echo "Output of AI wrapper: $out"

        for file in $out/bin/*; do
          echo "Processing $file"
          wrapProgram "$file" \
            --run 'export OPENAI_API_KEY="$(cat ${config.age.secrets.openai-key.path})"'
        done
      '';
    });
in {
  home.packages = with pkgs; [
    # Nix
    nix-prefetch
    # nix-visualize

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
    eza
    ripgrep
    fd
    sd
    xplr
    dua

    # Charm.sh pretty binaries
    gum
    charm
    (withOpenAi mods)
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

  home.sessionVariables = {
    USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
  };

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
