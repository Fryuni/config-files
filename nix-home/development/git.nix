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
    rustCrates.prr
  ];

  programs.git = {
    enable = true;

    userName = "Luiz Ferraz";
    userEmail = "luiz@lferraz.com";

    signing = {
      key = "2B568731DB2447EC";
      signByDefault = true;
    };

    delta = {
      enable = true;
      options = {
        features = "side-by-side line-numbers";
        navigate = true;
        dark = true;
      };
    };

    lfs.enable = true;

    includes = [
      {
        condition = "gitdir:~/IsoWorkspaces/Croct/";
        path = "${../../common/rcfiles/gitconfig_croct}";
      }
    ];

    extraConfig = {
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

  home.activation."fixGitMaintenance" = lib.hm.dag.entryAfter ["linkGeneration"] ''
    ${lib.escapeShellArgs [
      "${pkgs.sd}/bin/sd"
      "/nix/store/\\w+-git-[\\d.]+/"
      "${pkgs.git}/"
      "${config.home.homeDirectory}/.config/systemd/user/git-maintenance@.service"
    ]} || true
    systemctl --user daemon-reload || true
  '';
}
