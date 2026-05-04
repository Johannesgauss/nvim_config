-- ========================================================================== --
-- ==                           GENERAL SETTINGS                           == --
-- ========================================================================== --
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.mouse = 'a'
vim.opt.shiftwidth = 8
vim.opt.tabstop = 8
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.completeopt = 'menu,menuone,noselect'

-- Global Keymaps
vim.g.mapleader = " "
local key = vim.keymap.set
key('i', 'jk', '<Esc>')
key('i', '<C-c>', '<Esc>')
key('n', '<leader>', 'za') 
key('v', '<C-a>', ':w !xclip -i -sel c<CR><CR>') 

-- SDL / Qt Helpers
key('n', '<C-A-b>', ':!qmake && make && make clean && rm -f Makefile<CR>')
key('n', '<C-A-r>', ':!./Calculo<CR>')
key('n', '<C-t>', ':NERDTreeToggle<CR>:set relativenumber<CR>')

-- Use real tabs, not spaces
vim.opt.expandtab = false

-- How many visual spaces a TAB character occupies
vim.opt.tabstop = 8

-- How many spaces a 'control' (like indentation) occupies 
vim.opt.shiftwidth = 8

-- Makes the Tab key insert the appropriate number of spaces/tabs 
-- based on the settings above
vim.opt.softtabstop = 8

-- Create an autocommand group to keep things organized
local rust_tabs = vim.api.nvim_create_augroup("RustTabs", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
    pattern = "rust",
    group = rust_tabs,
    callback = function()
        vim.opt_local.expandtab = false   -- Force real tabs
        vim.opt_local.tabstop = 8        -- Visual width of a tab
        vim.opt_local.shiftwidth = 8     -- Width for auto-indent (>> and <<)
        vim.opt_local.softtabstop = 8    -- Behavior of Backspace/Tab keys
    end,
})
-- ========================================================================== --
-- ==                          PLUGIN MANAGEMENT                           == --
-- ========================================================================== --
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "neovim/nvim-lspconfig" }, -- Required for the underlying configs
  { "williamboman/mason.nvim", opts = {} },
  { "williamboman/mason-lspconfig.nvim", opts = { ensure_installed = { "clangd", "rust_analyzer" } } },
  { 'saghen/blink.cmp', version = '*', opts = { keymap = { preset = 'default' } } },
  { "preservim/nerdtree" },
  { "jiangmiao/auto-pairs" },
  { "rust-lang/rust.vim" },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
})

-- ========================================================================== --
-- ==                             LSP CONFIG                               == --
-- ========================================================================== --
-- Use the new Neovim 0.11 native way (replaces lspconfig.server.setup)
if vim.lsp.config then
    -- Modern 0.11+ way
    vim.lsp.enable('clangd')
    vim.lsp.enable('rust_analyzer')
else
    -- Fallback for 0.10 stable
    local lspconfig = require('lspconfig')
    lspconfig.clangd.setup({})
    lspconfig.rust_analyzer.setup({})
end

-- Keybindings that only activate when an LSP is connected
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local opts = { buffer = args.buf }
    
    -- This replaces <plug>(YCMHover) from your old Vim setup:
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.hover, opts)
    
    -- Other useful ones you might want:
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', '<C-s>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', 'ge', vim.diagnostic.open_float)
  end,
})
-- ========================================================================== --
-- ==                            APPEARANCE                                == --
-- ========================================================================== --
vim.cmd.colorscheme "catppuccin"
-- Force Neovim into 16-color mode for TTY compatibility
--		vim.opt.termguicolors = false
--		
--		local function hl(name, opts)
--		    vim.api.nvim_set_hl(0, name, opts)
--		end
--		
--		-- Keyword: Bright Red
--		-- GUI: Red | TTY: 9 (Bright Red)
--		hl("Keyword", { 
--		    fg = "#ff0000", 
--		    ctermfg = 9, 
--		    bold = true, 
--		    cterm = { bold = true } 
--		})
--		
--		-- Statement: Darker Red (to distinguish from Keywords)
--		-- GUI: Red | TTY: 1 (Standard Red)
--		hl("Statement", { 
--		    fg = "#ff0000", 
--		    ctermfg = 1,    
--		    bold = false, 
--		    cterm = { bold = false } 
--		})
--		
--		-- cConditional: Bright Red
--		-- GUI: Red | TTY: 9 (Bright Red)
--		hl("cConditional", { 
--		    fg = "#ff0000", 
--		    ctermfg = 9, 
--		    bold = false, 
--		    cterm = { bold = false } 
--		})
--		
--		-- Type: Bright Green (Keeping your previous green)
--		-- GUI: Green | TTY: 10 (Light Green)
--		hl("Type", { 
--		    fg = "#00ff00", 
--		    ctermfg = 10, 
--		    bold = false, 
--		    cterm = { bold = false } 
--		})
