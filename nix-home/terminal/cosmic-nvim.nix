{pkgs, ...}: {
  imports = [./cosmic-nvim.mod.nix];

  home.packages = with pkgs; [
    # luarocks
    # (tree-sitter.withPlugins (_: tree-sitter.allGrammars))
  ];

  programs.doom-nvim = {
    enable = true;
  };
}
