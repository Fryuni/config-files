{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    pkgs.nix-doc
  ];

  nix.package = pkgs.nix;
  nix.channel.enable = false;

  # nix.extraOptions = ''
  #   plugin-files = ${pkgs.nix-doc}/lib/libnix_doc_plugin.so
  # '';

  nix.optimise.automatic = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    substituters = [
      "https://nix-shell.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://nix-community.cachix.org"
      "https://nixpkgs.cachix.org"
      "https://fryuni.cachix.org"
    ];
    trusted-public-keys = [
      "nix-shell.cachix.org-1:kat3KoRVbilxA6TkXEtTN9IfD4JhsQp1TPUHg652Mwc="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
      "fryuni.cachix.org-1:YCNe73zqPG2YLIxxJkTXDz3/VFKcCiZAvHDIjEJIoDQ="
    ];

    # plugin-files = [
    #   "${pkgs.nix-doc}/lib/libnix_doc_plugin.so"
    # ];
  };

  nix.gc = {
    automatic = true;
    # interval = "weekly";
    options = "--delete-older-than 7d";
  };
}
