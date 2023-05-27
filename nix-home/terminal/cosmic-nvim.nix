{pkgs, ...}: {
  imports = [./cosmic-nvim.mod.nix];

  home.packages = with pkgs; [
    # luarocks
    # (tree-sitter.withPlugins (_: tree-sitter.allGrammars))
  ];

  programs.cosmic-nvim = {
    enable = true;
  };
}
