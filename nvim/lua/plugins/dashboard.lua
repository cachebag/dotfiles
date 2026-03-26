return {
  {
    "nvimdev/dashboard-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("dashboard").setup({
        theme = "hyper",
        config = {
          week_header = {
            enable = true,
          },
          shortcut = {
            { desc = " Find File", group = "Title", action = "Telescope find_files", key = "f" },
            { desc = " Live Grep", group = "Title", action = "Telescope live_grep", key = "g" },
            { desc = " Browser", group = "Title", action = "Neotree toggle", key = "e" },
            { desc = " Quit", group = "Title", action = "quit", key = "q" },
          },
        },
      })
    end,
  },
}
