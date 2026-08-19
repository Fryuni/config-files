final: pkgs: {
  astro-nvim = pkgs.stdenv.mkDerivation rec {
    pname = "astro-nvim";
    version = "v2.11.8";

    src = pkgs.fetchFromGitHub {
      owner = "AstroNvim";
      repo = "AstroNvim";
      rev = version;
      hash = "sha256-fpKrB6LW5KlQx/Egv5QY0hnzDGtJqmaXOzQevllVdjI=";
    };

    strictDeps = true;
    enableParallelBuilding = true;
    preferLocalBuild = true;
    allowSubstitutes = false;

    installPhase = ''
      mkdir -p $out
      cp init.lua $out/init.lua
      cp packer_snapshot $out/packer_snapshot
      cp -R lua $out/lua
      cp -R colors $out/colors
    '';

    passthru.updateScript = pkgs.nix-update-script {};
  };
}
