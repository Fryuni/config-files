final: pkgs:
(import ./jetbrains.nix final pkgs)
// (import ./pulumi final pkgs)
// {
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
    {inherit pkgs;};

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

  zellij = pkgs.rustPlatform.buildRustPackage rec {
    pname = "zellij";
    version = "0.33.0";

    doCheck = false;

    nativeBuildInputs = with pkgs; [
      openssl
      pkg-config
    ];

    src = pkgs.fetchCrate {
      inherit pname version;
      sha256 = "sha256-2o5JKotk5cwaN48ai5Pk7UmfIILXlZQbIR17Zus+Rjo=";
    };

    cargoSha256 = "sha256-YqNnKtyCF51x2RZTeB+xLVZpTFhqhVzUF7G796TvFmE=";
    cargoDepsName = pname;
  };

  cargo-doctor = pkgs.rustPlatform.buildRustPackage rec {
    pname = "cargo-doctor";
    version = "0.1.2";

    doCheck = false;

    nativeBuildInputs = with pkgs; [
      openssl
      pkg-config
    ];

    src = pkgs.fetchCrate {
      inherit pname version;
      sha256 = "";
    };
  };

  cargo-docs = pkgs.rustPlatform.buildRustPackage rec {
    pname = "cargo-docs";
    version = "0.1.24";

    doCheck = false;

    nativeBuildInputs = with pkgs; [
      openssl
      pkg-config
    ];

    src = pkgs.fetchCrate {
      inherit pname version;
      sha256 = "sha256-OxI+8JqSD6AoHx8AjRbWpXwIS/ER1U0vOqr2tFlNq4M=";
    };

    cargoSha256 = "sha256-tf/exlEHYar6IpUk7fJwrx4eo98uk4lE6W7J/7HyUp8=";
  };

  toml-merge = pkgs.rustPlatform.buildRustPackage rec {
    pname = "toml-merge";
    version = "0.1.0";
    doCheck = false;

    src = pkgs.fetchCrate {
      inherit pname version;
      sha256 = "sha256-0rB/6XpZSFEdBPTa6nt/EFSPncQso+w8syXHUYoYfaA=";
    };

    cargoSha256 = "sha256-BOBKbV4jInygN9l13jxi7guzdn5ao8owofomCdjXWng=";
    cargoDepsName = pname;
  };
}
