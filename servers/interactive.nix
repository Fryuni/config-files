{inputs, ...}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
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
    extraSpecialArgs = {
      inherit inputs;
    };
    users.lotus = {
      imports = [
        inputs.agenix.homeManagerModules.age
        ../nix-home
        ../nix-home/terminal/ai.nix
      ];
    };
  };
}
