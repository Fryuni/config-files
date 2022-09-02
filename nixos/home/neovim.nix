{ pkgs, ... }:
{
  # TODO: Follow this guide to the end: https://www.youtube.com/watch?v=rUvjkBuKua4

  xdg.configFile = {
    "nvim/parser/nix.so".source = "${pkgs.tree-sitter.builtGrammars.tree-sitter-nix}/parser";
  };

  programs.neovim = {
    enable = true;

    plugins = with pkgs.vimPlugins; [
      nvim-tree-lua
      nvim-treesitter

      vim-nix
    ];

    coc = {
      enable = true;
      settings = {
        languageserver = {
          nix = {
            command = "rnix-lsp";
            filetypes = [ "nix" ];
          };
        };
      };
    };

    vimAlias = true;
    viAlias = true;

    extraConfig = ''
      set number relativenumber
      set shiftwidth=2
    '';
  };
}
