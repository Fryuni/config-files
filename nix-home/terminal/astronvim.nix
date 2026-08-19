{pkgs, ...}: {
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
    "nvim/init.lua".source = "${pkgs.astro-nvim}/init.lua";
    "nvim/colors".source = "${pkgs.astro-nvim}/colors";
    "nvim/packer_snapshot".source = "${pkgs.astro-nvim}/packer_snapshot";
    "nvim/lua/configs".source = "${pkgs.astro-nvim}/lua/colors";
    "nvim/lua/core".source = "${pkgs.astro-nvim}/lua/core";
    "nvim/lua/default_theme".source = "${pkgs.astro-nvim}/lua/default_theme";
  };

  programs.bash.shellAliases = {vimdiff = "nvim -d";};
  programs.fish.shellAliases = {vimdiff = "nvim -d";};
  programs.zsh.shellAliases = {vimdiff = "nvim -d";};
}
