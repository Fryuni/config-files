{ config, lib, pkgs, ... }:
with lib;
let
  inherit (pkgs) stdenv;

  cfg = trivial.throwIf
    (config.programs.doom-nvim.enable && config.programs.neovim.enable)
    "Cannot enable neovim and doom-nvim modules at the same time."
    config.programs.doom-nvim;

  featureDependencies = with pkgs; {
    ranger = [ ranger ];
    lazygit = [ lazygit ];
    neogit = [ neogit ];
  };

  languageDependencies = with pkgs; {
    nix = {
      lsp = [ rnix-lsp ];
      linter = [ statix deadnix nixpkgs-fmt ];
    };
    lua = {
      lsp = [ sumneko-lua-language-server ];
      linter = [ luajitPackages.luacheck ];
    };
    go = {
      lsp = [ gopls ];
      linter = [ golangci-lint ];
    };
    # Do not add rls and rustfmt if rustup is installed already
    rust = mkIf (!builtins.elem rustup config.home.packages) {
      lsp = [ rls ];
      linter = [ rustfmt ];
    };
  };

in
{
  options = {
    programs.doom-nvim = {
      enable = mkEnableOption "DOOM Neovim";

      features = mkOption {
        type = types.listOf types.str;
        description = ''
          Features to be enabled on DOOM Neovim.
          The list of features is documented here:
          https://github.com/NTBBloodbath/doom-nvim/blob/main/docs/modules.md#features-modules
        '';
        default = [ ];
      };

      autoInstallBinaries = mkOption {
        type = types.bool;
        description = "When enabled, the binaries required to use a feature will be automatically included on `home.packages`.";
        default = true;
      };

      languages = mkOption {
        type = types.listOf types.str;
        description = ''
          Language support to enable.
          https://github.com/NTBBloodbath/doom-nvim/blob/main/docs/modules.md#features-modules
        '';
        default = [ ];
      };

      doom-nvim-src = {
        owner = mkOption {
          type = types.str;
          default = "NTBBloodbath";
        };
        repo = mkOption {
          type = types.str;
          default = "doom-nvim";
        };
        rev = mkOption {
          type = types.str;
          default = "v4.0.4";
        };
        sha256 = mkOption {
          type = types.str;
          default = "sha256-j12ffyr8WpY7NrngM59FmL3lnY6VfM3YjeeRD7ggqpU=";
        };
      };

      vimdiffAlias = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Alias <command>vimdiff</command> to <command>nvim -d</command>.
        '';
      };

      withNodeJs = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable node provider. Set to <literal>true</literal> to
          use Node plugins.
        '';
      };

      generatedModulesFile = mkOption {
        type = types.lines;
        visible = true;
        readOnly = true;
        description = ''
          Generated modules configuration.
        '';
      };

      mutableConfig = mkOption {
        type = types.bool;
        description = ''
          Write the configuration file as a mutable copy instead of a link.
          This allows actively exploring the configuration without new home-manager generations.
        '';
        default = false;
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
      };

      nvimPackage = mkOption {
        type = types.package;
        default = pkgs.neovim-unwrapped;
        defaultText = literalExpression "pkgs.neovim-unwrapped";
        description = "The package to use for the neovim binary.";
      };

      finalNvimPackage = mkOption {
        type = types.package;
        visible = false;
        readOnly = true;
        description = "Resulting customized neovim package.";
      };
    };
  };

  config =
    let

      neovimConfig = pkgs.neovimUtils.makeNeovimConfig {
        inherit (cfg) withNodeJs;
      };

      doom-src = stdenv.mkDerivation {
        pname = "doom-nvim";
        version = cfg.doom-nvim-src.rev;

        src = pkgs.fetchFromGitHub cfg.doom-nvim-src;

        strictDeps = true;
        enableParallelBuilding = true;
        preferLocalBuild = true;
        allowSubstitutes = false;

        installPhase = ''
          mkdir -p $out
          cp init.lua $out/init.lua
          cp -R lua $out/lua
          cp -R doc $out/docs
          cp -R colors $out/colors
        '';
      };

      featurePackages = lists.concatMap (feature: featureDependencies.${feature} or [ ]) cfg.features;

      languagePackages = lists.concatMap
        (language:
          lists.concatMap (feature: languageDependencies.${language}.${feature} or [ ]) cfg.features
        )
        cfg.languages;

    in
    mkIf cfg.enable {
      home.packages = [ cfg.finalNvimPackage ]
        ++ (lists.optionals cfg.autoInstallBinaries
        (featurePackages ++ languagePackages));

      programs.doom-nvim.generatedModulesFile = ''
        return {
          features = {
            ${concatMapStringsSep "\n    " (s: "\"${s}\",") cfg.features}
          },
          langs = {
            ${concatMapStringsSep "\n    " (s: "\"${s}\",") cfg.languages}
          },
        }
      '';

      xdg.configFile = {
        "nvim/init.lua".source = "${doom-src}/init.lua";
        "nvim/doc".source = "${doom-src}/docs";
        "nvim/colors".source = "${doom-src}/colors";
        "nvim/lua/doom".source = "${doom-src}/lua/doom";
        "nvim/lua/colors".source = "${doom-src}/lua/colors";

        "nvim/modules.lua".text = cfg.generatedModulesFile;

        # Must be linked even if empty.
        "nvim/config.lua" = mkIf (!cfg.mutableConfig) { text = cfg.extraConfig; };
        "nvim/config-hm.lua" = mkIf cfg.mutableConfig { text = cfg.extraConfig; };
      };

      home.activation = {
        "mutable doom-nvim" = mkIf cfg.mutableConfig (hm.dag.entryAfter [ "writeBoundary " ] ''
          if [ -f $HOME/.config/nvim/config.lua.bck ]; then
            mv $HOME/.config/nvim/config.lua.bck $HOME/.config/nvim/config.lua
          fi

          if [ ! -f $HOME/.config/nvim/config.lua ]; then
            echo "dofile('/home/lotus/.config/nvim/config-hm.lua')" > $HOME/.config/nvim/config.lua
            echo >> $HOME/.config/nvim/config.lua
            echo "-- Mutate the configuration below" >> $HOME/.config/nvim/config.lua
            echo >> $HOME/.config/nvim/config.lua
          fi
        '');
      };

      programs.doom-nvim.finalNvimPackage = pkgs.wrapNeovimUnstable cfg.nvimPackage
        (neovimConfig // {
          wrapRc = false;
        });

      programs.bash.shellAliases = mkIf cfg.vimdiffAlias { vimdiff = "nvim -d"; };
      programs.fish.shellAliases = mkIf cfg.vimdiffAlias { vimdiff = "nvim -d"; };
      programs.zsh.shellAliases = mkIf cfg.vimdiffAlias { vimdiff = "nvim -d"; };
    };
}