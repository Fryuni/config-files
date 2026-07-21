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
  nixpkgsHtmlManual = pkgs.nixpkgs-manual.overrideAttrs {
    postInstall = ''
      rm "$out/share/doc/nixpkgs/nixpkgs-manual.epub"
      sed -i '/nixpkgs-manual\.epub/d' "$out/nix-support/hydra-build-products"
    '';
  };
in {
  imports = [./docker.nix];

  environment.variables.EDITOR = "nvim";

  documentation.dev.enable = true;

  boot.kernelPackages = stableKernelPackages;

  environment.systemPackages = with pkgs; [
    neovim
    nixpkgsHtmlManual
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
