{inputs, ...}: {
  imports = [
    ./interactive.nix
  ];

  home-manager = {
    users.lotus = {
      imports = [
        ../nix-home/development
      ];
    };
  };
}
