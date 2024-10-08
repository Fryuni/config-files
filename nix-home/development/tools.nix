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
    corepack_20
    bun

    slack

    go
    golangci-lint
    gosec
    ngrok
    just
    master.turso-cli

    kubectl
    krew
    k9s
    kubernetes-helm
  ];

  home.sessionPath = [
    "$HOME/go/bin"
    "$HOME/.local/corepack"
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
