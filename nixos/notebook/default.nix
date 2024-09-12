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

  networking.hostName = "lotus-notebook";

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  services.dnscrypt-proxy2.settings.static.NextDNS.stamp = "sdns://AgEAAAAAAAAAAAAOZG5zLm5leHRkbnMuaW8TL2Y3ZmQ1MS9HNS1Ob3RlYm9vaw";

  nix.settings = {
    trusted-users = ["root" "lotus"];

    cores = 4;
    max-jobs = 4;
  };
}
