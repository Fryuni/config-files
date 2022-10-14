{ pkgs, ... }:
{
  imports = [ ./doom-nvim.mod.nix ];

  home.packages = with pkgs; [
    luarocks
    (tree-sitter.withPlugins (_: tree-sitter.allGrammars))
  ];

  programs.doom-nvim = {
    enable = true;

    doom-nvim-src = {
      owner = "Fryuni";
      repo = "doom-nvim";
      rev = "main";
      sha256 = "sha256-OqZYUub+ROLHrJmOijWBbR50cGcyzKqke9QJA2rfwgw=";
    };

    features = [
      # Language features
      "annotations" # Code annotation generator
      "auto_install" # Auto install LSP providers
      "autopairs" # Automatically close character pairs
      "comment" # Adds keybinds to comment in any language
      "linter" # Linting and formatting for languages
      "lsp" # Code completion
      "lsp_tests"
      "extra_snippets" # Code snippets for all languages

      # Editor
      "auto_session" # Remember sessions between loads
      "colorizer" # Show colors in neovim
      "editorconfig" # Support editorconfig files
      "gitsigns" # Show git changes in sidebar
      "illuminate" # Highlight other copies of the word you're hovering on
      "indentlines" # Show indent lines with special characters
      "range_highlight" # Highlight selected range from commands
      # "todo_comments" # Highlight TODO comments
      # "doom_themes" # Extra themes for doom

      # UI Components
      "lsp_progress" # Check status of LSP loading
      # "tabline" # Tab bar buffer switcher
      "dashboard" # A pretty dashboard upon opening
      "trouble" # A pretty diagnostic viewer
      # "statusline" # A pretty status line at the bottom of the buffer
      # "minimap" # Shows current position in document
      "terminal" # Integrated terminal in neovim
      "symbols" # Navigate between code symbols using telescope
      "ranger" # File explorer in neovim (TODO: Test)
      # "restclient" # Test HTTP requests from neovim (TODO: Test)
      # "show_registers" # Show and navigate between registers
      # "zen" # Distraction free mode

      # Tools
      "dap" # Debug code through neovim
      # "repl" # Interactive REPL in neovim
      # "explorer" # An enhanced filetree explorer
      # "firenvim" # Embed neovim in your browser
      "lazygit" # Lazy git integration
      # "neogit" # A git client for neovim
      # "neorg" # Organise your life
      "projects" # Quickly switch between projects
      # "superman" # Read unix man pages in neovim
      "suda" # Save using sudo when necessary
      "telescope" # Fuzzy searcher to find files, grep code and more
      "whichkey" # An interactive sheet
    ];

    languages = [
      # Scripts
      "lua"
      # "python"
      "bash"
      # "fish"
      # "gdscript"
      # "gdscript"
      # "php"

      # Web
      "javascript"
      "typescript"
      # "css"
      # "vue"
      # "tailwindcss"

      # Compiled
      "rust"
      # "cc"
      # "ocaml"
      "go"

      # JIT
      # "c_sharp"
      # "kotlin"
      # "java"

      "nix"
      "json"
      "yaml"
      "toml"
      "markdown"
      "terraform"
      "dockerfile"
    ];

    mutableConfig = true;

    luaUserFiles = "${builtins.getEnv "PWD"}/common/doom-nvim";

    extraConfig = ''
      doom.global_statusline = true
      doom.clipboard = false
      doom.preserve_edit_pos = true
      doom.indent = 2

      doom.use_keybind({
        { '<leader>', name = '+prefix', {
          {'y', name = "Yank to clipboard",    mode = 'v', '"+y'},
          {'p', name = "Paste from clipboard", mode = 'n', '"+p'},
        }}
      })

      local persistence = doom.features.auto_session
      persistence.settings.options = { "buffers", "curdir", "tabpages", "winsize" }
      persistence.binds = {
        "<leader>",
        name = "+prefix",
        {
          {
            "q",
            name = "+quit",
            {
              {
                "r",
                function() require("persistence").load() end,
                name = "Restore session",
              },
            },
          },
        },
      }

      local whichkey = doom.features.whichkey
      whichkey.settings.plugins.marks = true
      whichkey.settings.plugins.registers = true
      whichkey.settings.plugins.presets.operators = true

      local function run_action(action, offset)
        if action.edit or type(action.command) == "table" then
          if action.edit then
            vim.lsp.util.apply_workspace_edit(action.edit, offset)
          end
          if type(action.command) == "table" then
            vim.lsp.buf.execute_command(action.command)
          end
        else
          vim.lsp.buf.execute_command(action)
        end
      end

      local function do_action(action, client)
        if not action.edit
            and client
            and type(client.server_capabilities) == "table"
            and client.server_capabilities.resolveProvider
        then
          client.request("codeAction/resolve", action, function(err, real)
            if err then
              return
            end
            if real then
              run_action(real, client.offset_encoding)
            else
              run_action(action, client.offset_encoding)
            end
          end)
        else
          run_action(action, client.offset_encoding)
        end
      end

      local function run_all_similar()
        local params = vim.lsp.util.make_range_params() -- get params for current position
        params.context = {
          diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
          only = { "quickfix" },
        }

        local results, err = vim.lsp.buf_request_sync(
          0, -- current buffer
          "textDocument/codeAction", -- get code actions
          params,
          900
        )

        if err then
          return
        end

        if not results or vim.tbl_isempty(results) then
          print("No quickfixes!")
          return
        end

        -- we have an action!
        for cid, resp in pairs(results) do
          if resp.result then
            for _, result in pairs(resp.result) do
              -- this is the first action, run it
              do_action(result, vim.lsp.get_client_by_id(cid))
              return
            end
          end
        end

        print("No quickfixes!")
      end

      doom.use_keybind({
        { 'gA', name = "All code actions", run_all_similar },
      })
    '';
  };
}
