final: pkgs:
(import ./jetbrains.nix final pkgs)
  // {
  overlay-test = pkgs.writeShellScriptBin "overlay-hello" ''
    echo "This hellow world came from the custom derivation inside the overlay."
  '';

  nix-visualize = import
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

  zellij = pkgs.rustPlatform.buildRustPackage rec {
    pname = "zellij";
    version = "0.31.4";

    doCheck = false;

    nativeBuildInputs = with pkgs; [
      openssl
      pkg-config
    ];

    src = pkgs.fetchCrate {
      inherit pname version;
      sha256 = "sha256-v8rOQCLpEcrMb03lIGXIS2J0ex4fVZ0o8yj3iXb/Wxc=";
    };

    cargoSha256 = "sha256-XSbptD7lZCEsRoa3KxNOOjJcR0N/8gyL6t+RDb5NBQw=";
    cargoDepsName = pname;
  };
}
