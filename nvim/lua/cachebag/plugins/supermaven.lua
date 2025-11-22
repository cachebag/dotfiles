return {
  "supermaven-inc/supermaven-nvim",
  enabled = false,
  build = ":SupermavenUseFree",
  config = function()
    require("supermaven-nvim").setup({
      keymaps = {
        accept_suggestion = "<Tab>",
        clear_suggestion = "<C-]>",
        accept_word = "<C-j>",
      },
    })
  end,
}
