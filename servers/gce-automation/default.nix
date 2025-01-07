{pkgs, ...}: {
  imports = [
    ../common-gce.nix
  ];

  fileSystems."/data" = {
    fsType = "ext4";
    device = "/dev/disk/by-label/data";
    autoResize = true;
  };

  environment.systemPackages = with pkgs; [
    twitch-dl
    twitch-cli
  ];
}
