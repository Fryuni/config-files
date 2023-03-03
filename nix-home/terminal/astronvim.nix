{ config
, lib
, pkgs
, ...
}:
let
  inherit (pkgs) stdenv;

  astro-src = stdenv.mkDerivation rec {
    pname = "astro-nvim";
    version = "v2.11.8";

    src = pkgs.fetchFromGitHub {
      owner = "AstroNvim";
      repo = "AstroNvim";
      rev = version;
      sha256 = "sha256-fpKrB6LW5KlQx/Egv5QY0hnzDGtJqmaXOzQevllVdjI=";
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
  };
in
{
  home.packages = with pkgs; [
    neovim
    rnix-lsp
    nil
    statix
    deadnix
    alejandra
    gopls
    golangci-lint
  ];

  xdg.configFile = {
    "nvim/init.lua".source = "${astro-src}/init.lua";
    "nvim/colors".source = "${astro-src}/colors";
    "nvim/packer_snapshot".source = "${astro-src}/packer_snapshot";
    "nvim/lua/configs".source = "${astro-src}/lua/colors";
    "nvim/lua/core".source = "${astro-src}/lua/core";
    "nvim/lua/default_theme".source = "${astro-src}/lua/default_theme";
  };

  programs.bash.shellAliases = { vimdiff = "nvim -d"; };
  programs.fish.shellAliases = { vimdiff = "nvim -d"; };
  programs.zsh.shellAliases = { vimdiff = "nvim -d"; };
}
