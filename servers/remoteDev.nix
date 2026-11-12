{pkgs, ...}: {
  imports = [
    ./interactive.nix
  ];

  environment.systemPackages = with pkgs; [
    curl
    wget
    git
    dig
    htop
    btop
    gcc
    clang
    gnumake
    agenix
    (google-cloud-sdk.withExtraComponents (
      with google-cloud-sdk.components; [
        docker-credential-gcr
        beta
        alpha
        gsutil
        gke-gcloud-auth-plugin
        # terraform-tools
      ]
    ))
  ];

  home-manager = {
    users.lotus = {
      imports = [
        ../nix-home/development
      ];
    };
  };
}
