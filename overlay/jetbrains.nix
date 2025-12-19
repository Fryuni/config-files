final: pkgs: let
  jetbrains = pkgs.master.jetbrains;
  # jetbrains = pkgs.master.callPackage ./jetbrains {};

  globalPlugins = [
    # "acejump"
    # "ansi-highlighter-premium"
    # "asciidoc"
    # "aws-toolkit"
    # "better-direnv"
    # "catppuccin-icons"
    # "catppuccin-theme"
    # "code-complexity"
    # "codeglance-pro"
    # "cognitivecomplexity"
    # "continue"
    # "csv-editor"
    # "cucumber-for-java"
    # "darcula-pitch-black"
    # "dev-containers"
    # "developer-tools"
    "docker"
    # "dot-language"
    # "eclipse-keymap"
    # "extra-icons"
    # "extra-ide-tweaks"
    # "extra-tools-pack"
    # "extra-toolwindow-colorful-icons"
    # "ferris"
    # "file-watchers"
    # "gerry-themes"
    "gherkin"
    # "github-copilot"
    # "gitlab"
    "gittoolbox"
    # "go"
    # "go-template"
    "graphql"
    # "grep-console"
    # "handlebars-mustache"
    # "hocon"
    # "ide-features-trainer"
    "ideavim"
    # "indent-rainbow"
    # "ini"
    # "key-promoter-x"
    # "kotlin"
    # "mario-progress-bar"
    # "markdtask"
    # "maven-helper"
    "mermaid"
    # "mermaid-chart"
    # "minecraft-development"
    # "netbeans-6-5-keymap"
    # "nix-lsp"
    # "nixidea"
    # "oxocarbon"
    # "php-annotations"
    # "protocol-buffers"
    # "python"
    # "python-community-edition"
    # "rainbow-brackets"
    # "rainbow-csv"
    "randomness"
    # "rust"
    # "scala"
    # "string-manipulation"
    # "symfony-plugin"
    # "toml"
    # "visual-studio-keymap"
    # "vscode-keymap"
    "wakatime"
    # "which-key"
  ];

  overrides = {
    webstorm = {};
    goland = {};
    pycharm-professional = {};
    datagrip = {};
    rust-rover = {};
    idea-ultimate = {};
  };

  overrideFn = name: {
    noGlobalPlugins ? false,
    plugins ? [],
  }: let
    package = jetbrains.${name};
    idePlugins =
      if noGlobalPlugins
      then plugins
      else plugins ++ globalPlugins;
  in
    jetbrains.plugins.addPlugins package idePlugins;

  overridePkgs = builtins.mapAttrs overrideFn overrides;
in {
  jetbrains = jetbrains // overridePkgs;
}
