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
  };

  languageDependencies = with pkgs; {
    nix = [ rnix-lsp statix deadnix nixpkgs-fmt ];
    lua = [ sumneko-lua-language-server luajitPackages.luacheck ];
    go = [ gopls golangci-lint ];
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

      languages = mkOption {
        type = types.listOf types.str;
        description = ''
          Language support to enable.
          https://github.com/NTBBloodbath/doom-nvim/blob/main/docs/modules.md#features-modules
        '';
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

      extraConfig = mkOption {
        type = types.lines;
        default = "";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.neovim-unwrapped;
        defaultText = literalExpression "pkgs.neovim-unwrapped";
        description = "The package to use for the neovim binary.";
      };

      finalPackage = mkOption {
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
        customRC = cfg.extraConfig;
      };

      nixLanguageModule = ''
        local nix = {}

        nix.settings = {}

        nix.autocmds = {
          {
            "BufWinEnter",
            "*.nix",
            function()
              local langs_utils = require("doom.modules.langs.utils")

              langs_utils.use_lsp("rnix-lsp")

              require("nvim-treesitter.install").ensure_installed("nix")

              -- Setup null-ls
              if doom.features.linter then
                local null_ls = require("null-ls")
                langs_utils.use_null_ls_source({
                  -- null_ls.builtins.formatting.nixfmt,
                  null_ls.builtins.formatting.nixpkgs_fmt,
                  -- null_ls.builtins.formatting.alejandra,
                  null_ls.builtins.code_actions.statix,
                  null_ls.builtins.diagnostics.statix,
                  null_ls.builtins.diagnostics.deadnix,
                })
              end
            end,
            once = true,
          },
        }

        return nix
      '';

      doom-src = stdenv.mkDerivation {
        pname = "doom-nvim";
        version = cfg.doom-nvim-src.rev;

        src = pkgs.fetchFromGitHub rec {
          inherit (cfg.doom-nvim-src) rev sha256;

          owner = "NTBBloodbath";
          repo = "doom-nvim";
        };

        inherit nixLanguageModule;

        strictDeps = true;
        enableParallelBuilding = true;
        preferLocalBuild = true;
        allowSubstitutes = false;

        passAsFile = [ "nixLanguageModule" ];

        installPhase = ''
          mkdir -p $out
          cp init.lua $out/init.lua
          cp -R lua $out/lua
          cp -R doc $out/docs
          cp -R colors $out/colors
          mkdir -p $out/lua/doom/modules/langs/nix
          mv "$nixLanguageModulePath" $out/lua/doom/modules/langs/nix/init.lua
        '';
      };

      featurePackages = lists.concatMap (feature: featureDependencies.${feature} or [ ]) cfg.features;

      languagePackages = lists.concatMap (feature: languageDependencies.${feature} or [ ]) cfg.languages;

    in
    mkIf cfg.enable {
      home.packages = [
        cfg.finalPackage
      ]
      ++ featurePackages
      ++ languagePackages;

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

        # Must be linked even if empty.
        "nvim/config.lua".text = cfg.extraConfig;
        "nvim/modules.lua".text = cfg.generatedModulesFile;
      };

      programs.doom-nvim.finalPackage = pkgs.wrapNeovimUnstable cfg.package
        (neovimConfig // {
          wrapRc = false;
        });

      programs.bash.shellAliases = mkIf cfg.vimdiffAlias { vimdiff = "nvim -d"; };
      programs.fish.shellAliases = mkIf cfg.vimdiffAlias { vimdiff = "nvim -d"; };
      programs.zsh.shellAliases = mkIf cfg.vimdiffAlias { vimdiff = "nvim -d"; };
    };
}
