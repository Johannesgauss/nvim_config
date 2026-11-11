-- Enable Neovim's native Lua module bytecode loader cache for near-instant startup
if vim.loader then
  vim.loader.enable()
end

require("core.options")
require("core.keymaps")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { import = "plugins" },      -- core plugins
  require("modules").plugins(), -- optional authoring modules (markdown, latex, docx) gated by features.conf
  require("ai"),               -- AI specs injected directly
}, {
  change_detection = { enabled = false, notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        "netrwPlugin",
      },
    },
  },
})

require("ui.statusline")
require("ui.vim_look")
require("modules").setup()
