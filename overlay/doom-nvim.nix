final: pkgs: {
  doom-nvim = pkgs.stdenv.mkDerivation {
    pname = "doom-nvim";
    version = "unstable-2026-08-18";

    src = pkgs.fetchFromGitHub {
      owner = "Fryuni";
      repo = "doom-nvim";
      rev = "0ecefdf37c3dac4ba0c133bbe3a8102da745fa20";
      hash = "sha256-hqbgDPR3U1eEesM9Sxfcfo3oNFkMVN0UQboMYL8GkX4=";
    };

    strictDeps = true;
    enableParallelBuilding = true;
    preferLocalBuild = true;
    allowSubstitutes = false;

    installPhase = ''
      mkdir -p $out
      cp lazy-lock.json $out/lazy-lock.json
      cp init.lua $out/init.lua
      cp -R lua $out/lua
      cp -R doc $out/docs
      cp -R colors $out/colors
    '';

    passthru.updateScript = pkgs.nix-update-script {
      extraArgs = ["--version=branch=main"];
    };
  };
}
