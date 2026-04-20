{
  pkgs,
  lib,
  ...
}: {
  xdg.configFile = {
    "nvim/parser/nix.so".source = "${pkgs.tree-sitter.builtGrammars.tree-sitter-nix}/parser";
  };

  # Neovim config is managed in a separate repo — only provide the package and
  # runtime dependencies here without generating an init.lua wrapper.
  home.packages = with pkgs; [
    neovim
    tree-sitter
    gcc
  ];

  home.activation = {
    "clearNvimState" = lib.hm.dag.entryAfter ["linkGeneration"] ''
      HASH_TMP="$(mktemp)"
      echo ${pkgs.neovim} >> "$HASH_TMP"
      echo ${pkgs.neovim-unwrapped} >> "$HASH_TMP"
      echo ${pkgs.go} >> "$HASH_TMP"
      echo ${pkgs.tree-sitter} >> "$HASH_TMP"

      if ! diff -q "$HASH_TMP" ~/.local/state/nvim/nix_deps &>/dev/null ; then
        rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
      fi

      mkdir -p ~/.local/state/nvim
      mv "$HASH_TMP" ~/.local/state/nvim/nix_deps
    '';
  };
}
