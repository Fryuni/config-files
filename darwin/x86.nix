{...}: {
  imports = [
    ./homebrew.nix
    ../nixos/nix-settings.nix
    ../nixos/registries.nix
  ];

  nixpkgs.hostPlatform = "x86_64-darwin";
  networking.localHostName = "Fry-MacBook-x86";

  nix.settings = {
    trusted-users = ["root" "lotus" "@admin"];
  };

  services.nix-daemon.enable = true;
}
