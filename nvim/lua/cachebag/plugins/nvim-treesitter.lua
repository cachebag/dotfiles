return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "c",
          "lua",
          "vim",
          "vimdoc",
          "rust",
          "go",
          "cpp",
          "javascript",
          "html",
          "toml",
          "json",
          "markdown",
          "python",
          "yaml",
          "bash",
        },
        sync_install = false,
        auto_install = true,
        highlight = { 
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "gnn",
            node_incremental = "grn",
            scope_incremental = "grc",
            node_decremental = "grm",
          },
        },
      })
    end,
  },
  {
    "cachebag/nvim-tcss",
    config = true,
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/nvim-cmp",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
          }
        }
      })
      
      require("mason-lspconfig").setup({
        ensure_installed = {
          "clangd",      -- C++ LSP
          "lua_ls",      -- Lua LSP
          "pyright",     -- Python LSP
          "rust_analyzer", -- Rust LSP (Note: Mason uses rust_analyzer, not rust-analyzer)
        },
        automatic_installation = true,
      })
      
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      local lspconfig = require('lspconfig')
      
      -- C++ LSP setup
      lspconfig.clangd.setup({
        capabilities = capabilities,
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--completion-style=detailed",
          "--header-insertion=iwyu",
          "--suggest-missing-includes",
        },
      })
      
      -- Lua LSP setup
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        settings = {
          Lua = {
            runtime = {
              version = 'LuaJIT',
            },
            diagnostics = {
              globals = {'vim'},
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = {
              enable = false,
            },
          },
        },
      })
      
      -- Python LSP setup
      lspconfig.pyright.setup({
        capabilities = capabilities,
        settings = {
          python = {
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "workspace",
            },
          },
        },
      })
      
      -- Rust LSP setup (basic - rust-tools will enhance this)
      lspconfig.rust_analyzer.setup({
        capabilities = capabilities,
        settings = {
          ["rust-analyzer"] = {
            assist = {
              importEnforceGranularity = true,
              importPrefix = "crate"
            },
            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
            },
            procMacro = {
              enable = true,
            },
            checkOnSave = {
              enable = true,
              command = "clippy",
            },
          }
        }
      })
      
      -- Set up nvim-cmp
      local cmp = require('cmp')
      local luasnip = require('luasnip')
      
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp', priority = 1000 },
          { name = 'luasnip', priority = 750 },
          { name = 'crates', priority = 700 },
        }, {
          { name = 'buffer', priority = 500 },
          { name = 'path', priority = 250 },
        }),
        formatting = {
          format = function(entry, vim_item)
            vim_item.menu = ({
              nvim_lsp = "[LSP]",
              luasnip = "[Snippet]",
              buffer = "[Buffer]",
              path = "[Path]",
              crates = "[Crates]",
            })[entry.source.name]
            return vim_item
          end,
        },
        experimental = {
          ghost_text = true,
        },
      })
      
      -- Use buffer source for `/` and `?`
      cmp.setup.cmdline({ '/', '?' }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = 'buffer' }
        }
      })
      
      -- Use cmdline & path source for ':'
      cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = 'path' }
        }, {
          { name = 'cmdline' }
        })
      })
    end
  },
  {
    "simrat39/rust-tools.nvim",
    ft = "rust",
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-lua/plenary.nvim",
      "mfussenegger/nvim-dap",
    },
    config = function()
      local rt = require("rust-tools")
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      
      rt.setup({
        server = {
          capabilities = capabilities,
          on_attach = function(client, bufnr)
            -- Enable inlay hints if available
            if vim.lsp.inlay_hint then
              vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
            end
            
            -- Rust-specific keybindings
            local opts = { buffer = bufnr, silent = true }
            vim.keymap.set('n', '<leader>rh', rt.hover_actions.hover_actions, opts)
            vim.keymap.set('n', '<leader>ra', rt.code_action_group.code_action_group, opts)
          end,
          settings = {
            ["rust-analyzer"] = {
              assist = {
                importEnforceGranularity = true,
                importPrefix = "crate"
              },
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
              },
              procMacro = {
                enable = true,
              },
              checkOnSave = {
                enable = true,
                command = "clippy",
              },
              inlayHints = {
                bindingModeHints = {
                  enable = false,
                },
                chainingHints = {
                  enable = true,
                },
                closingBraceHints = {
                  enable = true,
                  minLines = 25,
                },
                closureReturnTypeHints = {
                  enable = "never",
                },
                lifetimeElisionHints = {
                  enable = "never",
                  useParameterNames = false,
                },
                maxLength = 25,
                parameterHints = {
                  enable = true,
                },
                reborrowHints = {
                  enable = "never",
                },
                renderColons = true,
                typeHints = {
                  enable = true,
                  hideClosureInitialization = false,
                  hideNamedConstructor = false,
                },
              },
            }
          }
        },
        tools = {
          hover_actions = {
            auto_focus = true,
          },
          inlay_hints = {
            show_parameter_hints = true,
            parameter_hints_prefix = "<- ",
            other_hints_prefix = "=> ",
          },
        },
      })
    end,
  },
  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("crates").setup({
        completion = {
          cmp = {
            enabled = true
          }
        },
        lsp = {
          enabled = true,
          actions = true,
          completion = true,
          hover = true,
        },
        popup = {
          autofocus = true,
        },
      })
      
      -- Add crates source to nvim-cmp for Cargo.toml files
      vim.api.nvim_create_autocmd("BufRead", {
        group = vim.api.nvim_create_augroup("CmpSourceCargo", { clear = true }),
        pattern = "Cargo.toml",
        callback = function()
          require("cmp").setup.buffer({ sources = { { name = "crates" } } })
        end,
      })
    end,
  },
}
