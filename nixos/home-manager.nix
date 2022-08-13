{ pkgs, home-manager, ... }:
{
  home-manager.useGlobalPkgs = true;
  home-manager.users.lotus = {
    home.packages = [ pkgs.httpie ];
    programs.bash.enable = true;
    home.stateVersion = "22.05";

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

    programs.git = {
      enable = true;
      delta.enable = true;

      userName = "Luiz Ferraz";
      userEmail = "luiz@lferraz.com";

      lfs.enable = true;

      extraConfig = {
  url = {
    # "ssh://git@github.com/" = { insteadOf = "https://github.com"; };
  };

  init.defaultBranch = "main";
      };
    };
    programs.gitui.enable = true;

    programs.ssh.enable = true;
    programs.gpg.enable = true;
    programs.gpg.mutableKeys = true;

    services.gpg-agent.enable = true;
    services.gpg-agent.pinentryFlavor = "tty";
  };
}
