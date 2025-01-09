{pkgs, ...}: {
  imports = [
    ../common-gce.nix
  ];

  fileSystems."/data" = {
    fsType = "ext4";
    device = "/dev/disk/by-id/google-data";
    autoResize = true;
  };

  environment.systemPackages = with pkgs; [
    twitch-dl
    twitch-cli
  ];

  environment.etc = {
    "downloader/download.sh".source = ./download.sh;
    "downloader/download-and-store.sh".source = ./download-and-store.sh;
  };
}
