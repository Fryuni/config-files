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
    stable.nodejs_22
    stable.corepack_22
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
      (name: _: {
        name = ".local/bin/${name}";
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
      ".ssh/config" = {
        target = ".ssh/config_source";
        onChange = ''cat .ssh/config_source > .ssh/config && chmod 400 .ssh/config'';
      };

      ".jvm/jdk11".source = "${pkgs.jdk11}";
      ".jvm/jdk21".source = "${pkgs.jdk21}";
    };

  age.secrets.node-red-key = {
    file = ../../secrets/node-red-key;
  };

  services.node-red = {
    enable = true;
    configFile = ../../common/node-red.js;
    repo = "git@gitlab.com:Fryuni/node-red-config.git";
    environment = {
      CREDENTIALS_FILE = config.age.secrets.node-red-key.path;
      GOOGLE_APPLICATION_CREDENTIALS = "${config.home.homeDirectory}/IsoWorkspaces/Croct/prod-env-deployer.json";
      CLOUDSDK_ACTIVE_CONFIG_NAME = "croct-sa";
    };
    # define = {
    #   "logging.console.level" = "trace";
    # };
  };
}
