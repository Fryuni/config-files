{ config, pkgs, sops-nix, ... }:
{
  environment.systemPackages = with pkgs; [
    pkgs.nix-doc
  ];

  nix.extraOptions = ''
    plugin-files = ${pkgs.nix-doc}/lib/libnix_doc_plugin.so
  '';

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    trusted-users = [ "root" "lotus" ];

    experimental-features = [ "nix-command" "flakes" ];

    auto-optimise-store = true;

    substituters =
      [ "https://nix-gaming.cachix.org" "https://nixpkgs.cachix.org" ];
    trusted-public-keys = [
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
}
