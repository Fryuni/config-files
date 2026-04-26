{...}: {
  imports = [
    ../nixos/sshHosts.nix
  ];

  networking.firewall.allowedTCPPorts = [22];

  services.openssh = {
    enable = true;
    ports = [22];
    settings = {
      AllowUsers = ["lotus"];
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.lotus = {
      home.username = "lotus";
      home.homeDirectory = "/home/lotus";
      home.stateVersion = "26.05";

      imports = [
        ../nix-home/terminal/ai.nix
        ../nix-home/development
      ];
    };
  };
}
