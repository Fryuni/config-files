{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    pkgs.nix-doc
  ];

  nix.settings = {
    trusted-users = ["root" "lotus"];

    experimental-features = [
      "nix-command"
      "flakes"
    ];

    auto-optimise-store = true;

    substituters = [
      "https://nix-shell.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://nix-community.cachix.org"
      "https://nixpkgs.cachix.org"
      "https://fryuni.cachix.org"
      "https://zig-overlay.cachix.org"
    ];
    trusted-public-keys = [
      "nix-shell.cachix.org-1:kat3KoRVbilxA6TkXEtTN9IfD4JhsQp1TPUHg652Mwc="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
      "fryuni.cachix.org-1:YCNe73zqPG2YLIxxJkTXDz3/VFKcCiZAvHDIjEJIoDQ="
      "zig-overlay.cachix.org-1:MCS36+WBxE8vqfE4j5BnCAx0Gse9EnTLSukAvP8JwtA="
    ];

    plugin-files = [];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
}
