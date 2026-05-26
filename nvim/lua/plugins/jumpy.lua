return {
    {
  "cachebag/jumpy",
  config = function()
    require("jumpy").setup({
      provider = "anthropic",
    })
  end,
    }
}
