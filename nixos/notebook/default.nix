{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    ../modules/development.nix
    ../modules/gaming.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  boot.blacklistedKernelModules = ["ideapad_laptop"];
  boot.extraModulePackages = with config.boot.kernelPackages; [zenpower];

  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  networking.hostName = "lotus-notebook";

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  services.dnscrypt-proxy2.settings.static.NextDNS.stamp = "sdns://AgEAAAAAAAAAAAAOZG5zLm5leHRkbnMuaW8TL2Y3ZmQ1MS9HNS1Ob3RlYm9vaw";

  users.mutableUsers = false;
  users.users.lotus.hashedPassword = "$6$5dd95KPYAytsdzt1$7auK5wgcz3xGilTjmUw./Acr9tNHQDBJn6n9Ob5bgBiL.vXOQQau.5tFhuF0uGkrI.36c8SK61m/P4kBFKoy60";

  nix.settings = {
    cores = 4;
    max-jobs = 4;
  };
}
