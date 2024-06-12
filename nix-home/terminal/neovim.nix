{
  pkgs,
  lib,
  ...
}: {
  # TODO: Follow this guide to the end: https://www.youtube.com/watch?v=rUvjkBuKua4

  xdg.configFile = {
    "nvim/parser/nix.so".source = "${pkgs.tree-sitter.builtGrammars.tree-sitter-nix}/parser";
  };

  programs.neovim = {
    enable = true;

    # plugins = with pkgs.vimPlugins; [
    #   nvim-tree-lua
    #   nvim-treesitter
    #
    #   vim-nix
    # ];
    #
    # vimAlias = true;
    # viAlias = true;
    #
    # extraConfig = ''
    #   set number relativenumber
    #   set shiftwidth=2
    # '';
  };

  home.activation = {
    "clear nvim" = lib.hm.dag.entryAfter ["writeBoundary"] ''
      rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
    '';
  };
}
