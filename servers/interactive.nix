{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.home-manager.nixosModules.home-manager];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
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
        ../nix-home/terminal
      ];
    };
  };
}
