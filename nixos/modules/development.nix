{
  config,
  pkgs,
  lib,
  stdenv,
  ...
}: {
  environment.variables.EDITOR = "nvim";

  documentation.dev.enable = true;

  boot.kernelPackages = pkgs.stable.linuxPackages;

  environment.systemPackages = with pkgs; [
    neovim
    inotify-tools
    gcc-unwrapped.lib
    gcc
    file
    termshark

    config.boot.kernelPackages.perf

    docker-compose
  ];

  virtualisation = {
    containerd.enable = true;

    docker = {
      enable = true;

      autoPrune.enable = true;
      autoPrune.dates = "weekly";
      autoPrune.flags = ["--all"];
    };
  };

  programs.wireshark.enable = true;

  services.dgraph = {
    enable = false;
  };
}
