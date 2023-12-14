{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    (python310.withPackages (py: [
      py.pyopenssl
    ]))
    nodejs_20
    nodePackages.yarn
    bun

    slack

    go_1_21
    golangci-lint
    gosec
    go2nix
    ngrok
    just
    master.turso-cli

    kubectl
    krew
    k9s
  ];

  home.sessionPath = [
    "$HOME/go/bin"
    "$HOME/.local/bin"
    "$HOME/.yarn/bin"
  ];

  home.file =
    lib.mapAttrs'
    (name: _: {
      name = ".local/bin/${name}";
      value = {
        source = ../../common/shellscripts/${name};
        executable = true;
      };
    })
    (lib.filterAttrs (_: typ: typ == "regular") (builtins.readDir ../../common/shellscripts));
}
