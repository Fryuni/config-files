{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;

    coc.enable = true;
    coc.settings = {
      languageserver = {
        nix = {
          command = "rnix-lsp";
          filetypes = [ "nix" ];
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
