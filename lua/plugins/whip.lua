if not require("core.features").is_enabled("whip") then
  return {}
end

return {
  {
    dir = "/home/paulo/whip",
    name = "whip.nvim",
    lazy = false,
    config = function()
      require("whip").setup({
        mode = "nudge",
        keymaps = {
          whip = "<leader>wl",
          slow = "<leader>ws",
          wrong = "<leader>ww",
          interrupt = "<leader>aW",
        },
      })
    end,
  },
}
