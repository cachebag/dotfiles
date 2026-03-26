return {
  -- nvim-cmp: Autocompletion engine
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      -- Snippet engine (required by nvim-cmp)
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",

      -- Completion sources
      "hrsh7th/cmp-nvim-lsp",     -- LSP completion source
      "hrsh7th/cmp-buffer",       -- Buffer completion source
      "hrsh7th/cmp-path",         -- Path completion source
      "hrsh7th/cmp-cmdline",      -- Command line completion
      "hrsh7th/cmp-nvim-lsp-signature-help", -- Function signatures

      -- Snippet collection (optional but useful)
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      -- Load friendly-snippets
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },

        -- Keybindings for completion menu
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),

        -- Completion sources (order matters for priority)
        sources = cmp.config.sources({
          { name = "nvim_lsp" },                -- LSP completions (rust-analyzer!)
          { name = "nvim_lsp_signature_help" }, -- Function signatures
          { name = "luasnip" },                 -- Snippets
          { name = "buffer", keyword_length = 3 }, -- Buffer words
          { name = "path" },                    -- File paths
        }),

        -- Formatting for completion menu
        formatting = {
          fields = { "kind", "abbr", "menu" },
          format = function(entry, vim_item)
            -- Kind icons
            local kind_icons = {
              Text = "",
              Method = "󰆧",
              Function = "󰊕",
              Constructor = "",
              Field = "󰇽",
              Variable = "󰂡",
              Class = "󰠱",
              Interface = "",
              Module = "",
              Property = "󰜢",
              Unit = "",
              Value = "󰎠",
              Enum = "",
              Keyword = "󰌋",
              Snippet = "",
              Color = "󰏘",
              File = "󰈙",
              Reference = "",
              Folder = "󰉋",
              EnumMember = "",
              Constant = "󰏿",
              Struct = "",
              Event = "",
              Operator = "󰆕",
              TypeParameter = "󰅲",
            }

            -- Set the icon
            vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind], vim_item.kind)

            -- Set the source name
            vim_item.menu = ({
              nvim_lsp = "[LSP]",
              luasnip = "[Snippet]",
              buffer = "[Buffer]",
              path = "[Path]",
              nvim_lsp_signature_help = "[Sig]",
            })[entry.source.name]

            return vim_item
          end,
        },

        -- Window appearance with borders
        window = {
          completion = cmp.config.window.bordered({
            border = "rounded",
            winhighlight = "Normal:CmpNormal,FloatBorder:CmpBorder,CursorLine:CmpSelection,Search:None",
          }),
          documentation = cmp.config.window.bordered({
            border = "rounded",
            winhighlight = "Normal:CmpDocNormal,FloatBorder:CmpDocBorder",
          }),
        },

        -- Experimental features
        experimental = {
          ghost_text = true, -- Show ghost text for completion
        },
      })

      -- Command-line completion for `/` search
      cmp.setup.cmdline("/", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" },
        },
      })

      -- Command-line completion for `:` commands
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = "path" },
        }, {
          { name = "cmdline" },
        }),
      })

      -- Set custom highlight groups for better visibility
      vim.api.nvim_set_hl(0, "CmpNormal", { bg = "#1e1e1e", fg = "#d4d4d4" })
      vim.api.nvim_set_hl(0, "CmpBorder", { bg = "#1e1e1e", fg = "#61afef" })
      vim.api.nvim_set_hl(0, "CmpSelection", { bg = "#3e4451", fg = "#e5c07b", bold = true })
      vim.api.nvim_set_hl(0, "CmpDocNormal", { bg = "#1e1e1e", fg = "#d4d4d4" })
      vim.api.nvim_set_hl(0, "CmpDocBorder", { bg = "#1e1e1e", fg = "#61afef" })

      -- Integrate autopairs with cmp
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },
}
