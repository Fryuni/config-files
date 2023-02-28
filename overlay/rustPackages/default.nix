pkgs: let
  generated = import ./data.nix;
  extras = import ./extras.nix pkgs;

  makePkg = name: definition: let
    extra = extras.${name} or {};
    safeExtras = builtins.removeAttrs extra ["nativeBuildInputs"];
  in
    pkgs.rustPlatform.buildRustPackage ({
        pname = name;
        inherit (definition) version;

        doCheck = false;

        nativeBuildInputs = with pkgs;
          (extra.nativeBuildInputs or [])
          ++ [
            openssl.dev
            pkg-config
          ];

        src = pkgs.fetchCrate {
          pname = name;
          inherit (definition) version;
          sha256 = definition.crateSha256;
        };

        cargoSha256 = definition.depsSha256;
        meta = {
          inherit (definition) description keywords;
          homepage = definition.homepage or "https://crates.io/crates/${name}";
          documentation = "https://docs.rs/${name}/${definition.version}";
          mainProgram = definition.mainProgram or null;
        };
      }
      // safeExtras);
in
  builtins.mapAttrs makePkg generated
