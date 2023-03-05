{
  pkgs,
  lib,
  stdenv,
  ...
}: {
  environment.variables.EDITOR = "nvim";

  documentation.dev.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    inotify-tools
    gcc-unwrapped.lib
    gcc
    file

    docker-compose
  ];

  systemd.enableUnifiedCgroupHierarchy = true;

  virtualisation = {
    containerd.enable = true;

    docker = {
      enable = true;

      autoPrune.enable = true;
      autoPrune.dates = "weekly";
      autoPrune.flags = ["--all"];
    };
  };

  services.dgraph = {
    enable = false;
  };
}
