{ pkgs, lib, ... }:
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
    "$HOME/go/bin"
    "$HOME/.local/bin"
  ];

  home.file = lib.mapAttrs'
    (name: _: {
      name = ".local/bin/${name}";
      value = {
        source = ../../common/shellscripts/${name};
        executable = true;
      };
    })
    (lib.filterAttrs (_: typ: typ == "regular") (builtins.readDir ../../common/shellscripts));
}
