final: prev: let
  inherit (final.fenix.complete) toolchain;
  rustPlatform = final.makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  };

  generated = import ./data.nix;
  extras = import ./extras.nix final;

  makePkg = name: definition: let
    extra = extras.${name} or {};
    safeExtras = builtins.removeAttrs extra ["nativeBuildInputs"];
  in
    final.rustPlatform.buildRustPackage ({
        pname = name;
        inherit (definition) version;

        doCheck = false;

        nativeBuildInputs = with final;
          (extra.nativeBuildInputs or [])
          ++ [pkg-config];

        src = final.fetchCrate {
          pname = name;
          inherit (definition) version;
          sha256 = definition.crateSha256;
        };

        cargoSha256 = definition.depsSha256;
        meta = {
          inherit (definition) description keywords;
          homepage = definition.homepage or "https://crates.io/crates/${name}";
          documentation = "https://docs.rs/${name}/${definition.version}";
          mainProgram = definition.mainProgram or name;
          maintainers = [final.lib.maintainers.fryuni];
        };
      }
      // safeExtras);
in {
  fenixPlatform = rustPlatform;
  rustCrates = builtins.mapAttrs makePkg generated;
}
