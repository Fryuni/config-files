{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    (python313.withPackages (py: [
      py.pyopenssl
    ]))
    nodejs_25
    corepack
    bun

    libnotify
    slack
    insomnia

    # GoLang
    go
    golangci-lint
    gosec

    ngrok
    just
    master.turso-cli
    zigpkgs.master

    # LSPs
    gopls # Go LSP
    marksman # Markdown LSP
    nil # Nix LSP
    nixd # Nix LSP - Daemon
    deadnix
    selene # Lua LSP - Linter
    sqls
    ty # Python LSP
    zigpkgs.master.zls
    htmx-lsp2
    just-lsp
    postgres-language-server
    astro-language-server
    bash-language-server
    java-language-server
    lua-language-server
    mdx-language-server
    typescript-language-server
    yaml-language-server

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

  home.file = let
    shellscripts =
      lib.mapAttrs'
      (name: _: let
        matchResult = builtins.match "(.*)\\.[^.]*" name;
        nameWithoutExt =
          if matchResult == null
          then name
          else builtins.elemAt matchResult 0;
      in {
        name = ".local/bin/${nameWithoutExt}";
        value = {
          source = ../../common/shellscripts/${name};
          executable = true;
        };
      })
      (lib.filterAttrs (_: typ: typ == "regular") (builtins.readDir ../../common/shellscripts));
  in
    shellscripts
    // {
      # Hack to fix SSH warnings/errors due to a file permissions check in some tools
      # ".ssh/config" = {
      #   target = ".ssh/config_source";
      #   onChange = ''cat .ssh/config_source > .ssh/config && chmod 400 .ssh/config'';
      # };

      ".jvm/jdk11".source = "${pkgs.jdk11}";
      ".jvm/jdk21".source = "${pkgs.jdk21}";
    };
}
