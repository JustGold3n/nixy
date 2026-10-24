{
  pkgs,
  lib,
  ...
}: {
  vim = {
    extraPackages = with pkgs; [
      cargo
      clippy
      rustc
    ];

    diagnostics = {
      enable = true;
      config = {
        signs = {
          text = {
            "vim.diagnostic.severity.Error" = " ";
            "vim.diagnostic.severity.Warn" = " ";
            "vim.diagnostic.severity.Hint" = " ";
            "vim.diagnostic.severity.Info" = " ";
          };
        };
        underline = true;
        update_in_insert = true;
        virtual_text = true;
      };
      nvim-lint = {
        enable = true;
      };
    };
    treesitter = {
      enable = true;
      autotagHtml = true;
      context.enable = true;
      highlight.enable = true;
      textobjects.enable = true;
      grammars = [
        pkgs.vimPlugins.nvim-treesitter.grammarPlugins.http
        pkgs.vimPlugins.nvim-treesitter.grammarPlugins.tsx
      ];
    };
    lsp = {
      enable = true;
      presets = {
        tailwindcss-language-server = {
          enable = true;
        };
        vtsls = {
          enable = true;
        };
      };
      trouble.enable = true;
      lspSignature.enable = true;
      lspconfig.enable = true;
      formatOnSave = false;
      mappings.format = null;
      inlayHints.enable = true;
      servers.nil.settings.nix.autoArchive = true;
      servers.astro-language-server.before_init = lib.mkForce (lib.generators.mkLuaInline ''
        function(_, config)
          local typescript = config.init_options.typescript
          if not typescript.tsdk or typescript.tsdk == "" then
            local project_sdk = util.get_typescript_server_path(config.root_dir)
            -- Astro needs the JavaScript SDK, which TypeScript 7 no longer ships.
            local has_sdk = project_sdk ~= "" and vim.uv.fs_stat(project_sdk .. "/typescript.js")
            typescript.tsdk = has_sdk and project_sdk
              or "${pkgs.typescript}/lib/node_modules/typescript/lib"
          end
        end
      '');
      servers.rust-analyzer.settings."rust-analyzer" = {
        cargo = {
          allTargets = true;
          buildScripts.enable = true;
        };
        check = {
          allTargets = true;
          command = "clippy";
        };
        completion = {
          autoimport.enable = true;
          callable.snippets = "fill_arguments";
          fullFunctionSignatures.enable = true;
          postfix.enable = true;
        };
        inlayHints = {
          closureReturnTypeHints.enable = "with_block";
          lifetimeElisionHints.enable = "skip_trivial";
        };
        procMacro.enable = true;
      };
      otter-nvim = {
        enable = true;
        setupOpts = {
          buffers.set_filetype = true;
          lsp = {
            diagnostic_update_event = [
              "BufWritePost"
              "InsertLeave"
            ];
          };
        };
      };
      lspkind.enable = true;
      lspsaga = {
        enable = true;
        setupOpts = {
          ui = {
            code_action = "";
          };
          lightbulb = {
            sign = false;
            virtual_text = true;
          };
          symbol_in_winbar.enable = false;
        };
      };
    };
    languages = {
      enableExtraDiagnostics = true;
      enableFormat = true;
      enableTreesitter = true;

      python = {
        enable = true;
        lsp = {
          enable = true;
          servers = ["pyright"];
        };
      };
      rust = {
        enable = true;
        treesitter.enable = true;
        lsp.enable = true;
        format = {
          enable = true;
          type = ["rustfmt"];
        };
        dap = {
          enable = true;
          debugger = ["codelldb"];
        };
        extensions.crates-nvim.enable = true;
      };
      toml.enable = true;
      astro = {
        enable = true;
        treesitter.enable = true;
        lsp = {
          enable = true;
          servers = ["astro-language-server"];
        };
        # nvf includes prettier-plugin-astro with this formatter.
        format = {
          enable = true;
          type = ["prettier"];
        };
      };
      go.enable = true;
      markdown = {
        enable = true;
        format.type = ["prettier"];
        extensions = {
          markview-nvim = {
            enable = true;
            setupOpts = {
              preview = {
                hybrid_modes = ["n"];
              };
            };
          };
        };
        extraDiagnostics.enable = false;
      };
      typescript = {
        enable = true;
        # vtsls preset used instead: ts_ls here misses .tsx filetypes
        lsp.servers = [];
      };
      css.enable = true;
      svelte.enable = true;
      html.enable = true;
      bash.enable = true;
      nix.enable = true;
      lua.enable = true;
    };
    formatter = {
      conform-nvim = {
        enable = true;
        setupOpts.format_on_save = {
          lsp_format = "fallback";
        };
      };
    };
    debugger.nvim-dap.ui.enable = true;
  };
}
