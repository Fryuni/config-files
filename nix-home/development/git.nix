{
  pkgs,
  lib,
  config,
  ...
}: {
  home.packages = with pkgs; [
    # Git stuff
    gh
    lazygit
  ];

  programs.git = {
    enable = true;

    signing = {
      key = "2B568731DB2447EC";
      signByDefault = true;
    };

    lfs.enable = true;

    includes = [
      {
        condition = "gitdir:~/IsoWorkspaces/Croct/";
        path = "${../../common/rcfiles/gitconfig_croct}";
      }
    ];

    settings = {
      user.name = "Luiz Ferraz";
      user.email = "luiz@lferraz.com";

      url = {
        "ssh://git@github.com/" = {insteadOf = "https://github.com/";};
        "ssh://git@gitlab.com/" = {insteadOf = "https://gitlab.com/";};
      };

      core.excludesfile = "${../../common/rcfiles/gitignore}";

      alias = {
        # Worktree
        wt = "worktree";
        wtl = "worktree list";
        wta = "worktree add";
        wtp = "worktree prune";
      };

      init.defaultBranch = "main";
      tag.gpgSign = true;

      push.default = "upstream";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      features = "side-by-side line-numbers";
      navigate = true;
      dark = true;
    };
  };

  programs.zsh.shellAliases = {
    gcpr = "gh pr list | cut -f1,2 | gum filter --height=10 --limit=1 --select-if-one | cut -f1 | xargs gh pr checkout";
  };

  home.activation."fixGitMaintenance" = lib.hm.dag.entryAfter ["linkGeneration"] ''
    ${lib.escapeShellArgs [
      "${pkgs.sd}/bin/sd"
      "/nix/store/\\w+-git-[\\d.]+/"
      "${pkgs.git}/"
      "${config.home.homeDirectory}/.config/systemd/user/git-maintenance@.service"
    ]} || true
    ${pkgs.systemd}/bin/systemctl --user daemon-reload || true
  '';
}
