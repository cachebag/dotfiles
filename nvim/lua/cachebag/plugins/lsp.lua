return {
  {
    "neovim/nvim-lspconfig",

    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",  -- needed for capabilities
    },

    config = function()
      -- mason
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "clangd",
          "lua_ls",
          "pyright",
          "rust_analyzer",
          "astro",
          "jdtls",
        },
      })

      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local cfg = vim.lsp.config

      cfg["clangd"] = {
        capabilities = capabilities,
        filetypes = { "c", "cpp", "objc", "objcpp" },
      }

      cfg["lua_ls"] = {
        capabilities = capabilities,
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim", "require" } },
            workspace = {
              library = {
                vim.env.VIMRUNTIME,
                vim.fn.stdpath("config"),
              },
              checkThirdParty = false,
            },
          },
        },
      }

      cfg["pyright"] = {
        capabilities = capabilities,
      }

      cfg["rust_analyzer"] = {
        capabilities = capabilities,
        cmd = { "rustup", "run", "stable", "rust-analyzer" },
        settings = {
          ["rust-analyzer"] = {
            check = { command = "clippy" },
            inlayHints = { enable = true },
          },
        },
      }

      cfg["astro"] = {
        capabilities = capabilities,
      }

      cfg["jdtls"] = {
        capabilities = capabilities,
      }

      -- enable all configured servers
      for name, _ in pairs(cfg) do
        vim.lsp.enable(name)
      end
    end,
  },
}
