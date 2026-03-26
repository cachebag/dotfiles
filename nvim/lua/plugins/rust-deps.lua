return {
  -- Crates.nvim: Cargo.toml dependency management
  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("crates").setup({
        -- Display settings
        text = {
          loading = "   Loading",
          version = "   %s",
          prerelease = "   %s",
          yanked = "   %s",
          nomatch = "   No match",
          upgrade = "   %s",
          error = "   Error fetching crate",
        },

        -- Highlight groups
        highlight = {
          loading = "CratesNvimLoading",
          version = "CratesNvimVersion",
          prerelease = "CratesNvimPreRelease",
          yanked = "CratesNvimYanked",
          nomatch = "CratesNvimNoMatch",
          upgrade = "CratesNvimUpgrade",
          error = "CratesNvimError",
        },

        -- Enable popup for crate details
        popup = {
          autofocus = true,
          hide_on_select = false,
          copy_register = '"',
          style = "minimal",
          border = "rounded",
          show_version_date = true,
          show_dependency_version = true,
          max_height = 30,
          min_width = 20,
          padding = 1,
        },

        -- Use in-process language server for completions and diagnostics
        lsp = {
          enabled = true,
          on_attach = function(client, bufnr)
            -- LSP is now attached for Cargo.toml
          end,
          actions = true,
          completion = true,
          hover = true,
        },

        -- Enable all features
        enable_update_available_warning = true,
      })

      -- Set up autocommands for Cargo.toml
      vim.api.nvim_create_autocmd("BufRead", {
        group = vim.api.nvim_create_augroup("CmpSourceCargo", { clear = true }),
        pattern = "Cargo.toml",
        callback = function()
          -- Set up keymaps for Cargo.toml buffers
          local opts = { buffer = true, silent = true }

          -- Version operations
          vim.keymap.set("n", "<leader>ct", require("crates").toggle, opts)
          vim.keymap.set("n", "<leader>cr", require("crates").reload, opts)

          -- Show crate information
          vim.keymap.set("n", "<leader>cv", require("crates").show_versions_popup, opts)
          vim.keymap.set("n", "<leader>cf", require("crates").show_features_popup, opts)
          vim.keymap.set("n", "<leader>cd", require("crates").show_dependencies_popup, opts)

          -- Update operations
          vim.keymap.set("n", "<leader>cu", require("crates").update_crate, opts)
          vim.keymap.set("v", "<leader>cu", require("crates").update_crates, opts)
          vim.keymap.set("n", "<leader>ca", require("crates").update_all_crates, opts)
          vim.keymap.set("n", "<leader>cU", require("crates").upgrade_crate, opts)
          vim.keymap.set("v", "<leader>cU", require("crates").upgrade_crates, opts)
          vim.keymap.set("n", "<leader>cA", require("crates").upgrade_all_crates, opts)

          -- Expand/collapse crate details
          vim.keymap.set("n", "<leader>cx", require("crates").expand_plain_crate_to_inline_table, opts)
          vim.keymap.set("n", "<leader>cX", require("crates").extract_crate_into_table, opts)

          -- Navigate to homepage/docs/repo
          vim.keymap.set("n", "<leader>cH", require("crates").open_homepage, opts)
          vim.keymap.set("n", "<leader>cR", require("crates").open_repository, opts)
          vim.keymap.set("n", "<leader>cD", require("crates").open_documentation, opts)
          vim.keymap.set("n", "<leader>cC", require("crates").open_crates_io, opts)
        end,
      })

      -- Set up highlight groups with sane defaults
      vim.api.nvim_set_hl(0, "CratesNvimLoading", { fg = "#808080", italic = true })
      vim.api.nvim_set_hl(0, "CratesNvimVersion", { fg = "#98c379" })
      vim.api.nvim_set_hl(0, "CratesNvimPreRelease", { fg = "#e5c07b" })
      vim.api.nvim_set_hl(0, "CratesNvimYanked", { fg = "#e06c75" })
      vim.api.nvim_set_hl(0, "CratesNvimNoMatch", { fg = "#e06c75" })
      vim.api.nvim_set_hl(0, "CratesNvimUpgrade", { fg = "#61afef", bold = true })
      vim.api.nvim_set_hl(0, "CratesNvimError", { fg = "#e06c75", bold = true })
    end,
  },
}
