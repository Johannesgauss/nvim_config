local opt = vim.opt

-- Automatically ensure user bin directories are in PATH across all environments (rg, fd, etc.)
local home = vim.env.HOME or vim.fn.expand("~")
local standard_bin_paths = { home .. "/.local/bin", home .. "/.cargo/bin", "/usr/local/bin" }
for _, dir in ipairs(standard_bin_paths) do
    if vim.fn.isdirectory(dir) == 1 and not string.find(vim.env.PATH, dir, 1, true) then
        vim.env.PATH = dir .. ":" .. vim.env.PATH
    end
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

opt.splitright = true
opt.laststatus = 2
opt.number = true
opt.relativenumber = true
opt.clipboard = "unnamedplus"
opt.smartindent = true
opt.tabstop = 8
opt.shiftwidth = 8
opt.expandtab = false

vim.api.nvim_create_autocmd({"WinEnter", "BufWinEnter", "TermOpen"}, {
    pattern = "term://*",
    callback = function() vim.cmd("startinsert") end,
})

vim.api.nvim_create_autocmd("TermOpen", {
    callback = function()
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
    end,
})

vim.api.nvim_create_autocmd("TermClose", {
    callback = function()
        vim.cmd("bdelete!")
    end,
})

vim.filetype.add({
  extension = {
    prisma = "prisma",
  },
})

