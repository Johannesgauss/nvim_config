local opt = vim.opt

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
opt.expandtab = true

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

