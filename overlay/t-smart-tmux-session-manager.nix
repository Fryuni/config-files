final: pkgs: {
  t-smart-tmux-session-manager = pkgs.tmuxPlugins.t-smart-tmux-session-manager.overrideAttrs (_: {
    version = "unstable-2026-05-22";
    src = pkgs.fetchgit {
      url = "https://codeberg.org/Fryuni/t-smart-tmux-session-manager.git";
      rev = "57d83d65feb692904644f162881977ffc54644d2";
      hash = "sha256-DrWNLAXgKH6Kf/NPMFz4nsk6GAjXDlPhLU/cSu6q+lo=";
    };

    passthru.updateScript = pkgs.nix-update-script {
      extraArgs = ["--version=branch=main"];
    };
  });
}
