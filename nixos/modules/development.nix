{pkgs, ...}: {
  imports = [./docker.nix];

  environment.variables.EDITOR = "nvim";

  documentation.dev.enable = true;

  boot.kernelPackages = pkgs.stable.linuxPackages;

  environment.systemPackages = with pkgs; [
    neovim
    inotify-tools
    gcc-unwrapped.lib
    gcc
    file
    # termshark
    perf
    docker-compose
  ];

  programs.wireshark.enable = false;
}
