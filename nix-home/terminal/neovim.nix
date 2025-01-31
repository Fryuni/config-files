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
    "clearNvimState" = lib.hm.dag.entryAfter ["linkGeneration"] ''
      HASH_TMP="$(mktemp)"
      echo ${pkgs.neovim} >> "$HASH_TMP"
      echo ${pkgs.neovim-unwrapped} >> "$HASH_TMP"
      echo ${pkgs.go} >> "$HASH_TMP"

      if ! diff -q "$HASH_TMP" ~/.local/state/nvim/nix_deps &>/dev/null ; then
        rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
      fi

      mkdir -p ~/.local/state/nvim
      mv "$HASH_TMP" ~/.local/state/nvim/nix_deps
    '';
  };
}
