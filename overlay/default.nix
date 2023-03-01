final: pkgs:
(import ./jetbrains.nix final pkgs)
// (import ./pulumi final pkgs)
// (import ./rustPackages final)
  // {
  lib = pkgs.lib // {
    maintainers = pkgs.lib.maintainers // {
      fryuni = {
        name = "Luiz Ferraz";
        github = "Fryuni";
        gitlab = "Fryuni";
        email = "luiz@lferraz.com";
      };
    };
  };
  # ksp-ckan = pkgs.callPackage ./ckan.nix {};

  # neovim = pkgs.stable.neovim;
  # neovim-unwrapped = pkgs.stable.neovim-unwrapped;
  # wrapNeovimUnstable = pkgs.stable.wrapNeovimUnstable;

  nix-visualize =
    import
      (pkgs.fetchFromGitHub {
        owner = "craigmbooth";
        repo = "nix-visualize";
        rev = "ee6ad3cb3ea31bd0e9fa276f8c0840e9025c321a";
        sha256 = "sha256-nsD5U70Ue30209t4fU8iMLCHzNZo18wKFutaFp55FOw=";
      })
      { inherit pkgs; };

  grafterm = pkgs.buildGoModule rec {
    pname = "grafterm";
    version = "0.2.0";

    src = pkgs.fetchFromGitHub {
      owner = "slok";
      repo = "grafterm";
      rev = "v0.2.0";
      sha256 = "sha256-0pM36rAmwx/P1KAlmVaGoSj8eb9JucYycNC2R867dVo=";
    };

    vendorSha256 = "sha256-veg5B68AQhkSZg8YA/e4FbqJNG0YGwnUQFsAdscz0QI=";
  };
}
