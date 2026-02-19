return {
  "supermaven-inc/supermaven-nvim",
  enabled = true,
  build = ":SupermavenUseFree",
  config = function()
    require("supermaven-nvim").setup({
      disable_keymaps = true,
      keymaps = {
        accept_suggestion = "<Tab>",
        clear_suggestion = "<C-]>",
        accept_word = "<C-j>",
      },
    })
  end,
}
