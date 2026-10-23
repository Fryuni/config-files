{pkgs, ...}: let
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
