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
    gnumake
    agenix
  ];

  home-manager = {
    users.lotus = {
      imports = [
        ../nix-home/development
      ];
    };
  };
}
