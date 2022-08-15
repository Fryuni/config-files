{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rustup
    nodejs-18_x
    nodePackages.yarn

    go_1_19
    golangci-lint
    gosec
    go2nix
  ];

  home.sessionPath = [
    "$HOME/.cargo/bin"
  ];
}
