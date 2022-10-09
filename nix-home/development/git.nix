_:
{
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
        delta.navigate = true;
      };
    };

    lfs.enable = true;

    extraConfig = {
      url = {
        "ssh://git@github.com/" = { insteadOf = "https://github.com/"; };
        "ssh://git@gitlab.com/" = { insteadOf = "https://gitlab.com/"; };
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
    };
  };
}
