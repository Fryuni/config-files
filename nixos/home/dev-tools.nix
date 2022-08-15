{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rustup
    nodejs-18_x
    nodePackages.yarn
  ];

  home.sessionPath = [
    "$HOME/.cargo/bin"
  ];
}
