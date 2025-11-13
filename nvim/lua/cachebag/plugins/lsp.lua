return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/nvim-cmp",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      require("mason").setup({})
      require("mason-lspconfig").setup({
        ensure_installed = { "clangd", "lua_ls", "pyright", "rust_analyzer", "astro", "jdtls" },
        automatic_installation = true,
      })

      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      vim.lsp.enable("clangd", {
        capabilities = capabilities,
        filetypes = { "c", "cpp", "objc", "objcpp" },
      })

      vim.lsp.enable("lua_ls", {
        capabilities = capabilities,
        filetypes = { "lua" },
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = { enable = false },
          },
        },
      })

      vim.lsp.enable("pyright", {
        capabilities = capabilities,
        filetypes = { "python" },
      })

      vim.lsp.enable("rust_analyzer", {
        capabilities = capabilities,
        filetypes = { "rust" },
        cmd = { "rustup", "run", "stable", "rust-analyzer" },
      })

      vim.lsp.enable("astro", {
        capabilities = capabilities,
        filetypes = { "astro" },
        init_options = {
          typescript = {
            tsdk = vim.fn.stdpath("data")
              .. "/mason/packages/typescript-language-server/node_modules/typescript/lib",
          },
        },
      })

      vim.lsp.enable("jdtls", {
        capabilities = capabilities,
        filetypes = { "java" },
      })

      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = {
          { name = "nvim_lsp" },
          { name = "buffer" },
          { name = "path" },
        },
      })
    end,
  },
}
