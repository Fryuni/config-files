{pkgs, ...}: let
  stableKernelPackages = pkgs.stable.linuxPackages.extend (_: prev: {
    kernel = prev.kernel.overrideAttrs (oldAttrs: {
      passthru =
        (oldAttrs.passthru or {})
        // {
          target = oldAttrs.passthru.target or pkgs.stable.stdenv.hostPlatform.linux-kernel.target;
          buildDTBs = oldAttrs.passthru.buildDTBs or (pkgs.stable.stdenv.hostPlatform.linux-kernel.DTB or false);
        };
    });
  });
in {
  imports = [./docker.nix];

  environment.variables.EDITOR = "nvim";

  documentation.dev.enable = true;

  boot.kernelPackages = stableKernelPackages;

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
