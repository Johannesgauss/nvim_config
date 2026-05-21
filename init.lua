-- ========================================================================== --
-- ==                         BOOTSTRAP LAZY.NVIM                          == --
-- ========================================================================== --
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- ========================================================================== --
-- ==                           GENERAL SETTINGS                           == --
-- ========================================================================== --
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.mouse = "a"
vim.opt.expandtab = false
vim.opt.tabstop = 8
vim.opt.shiftwidth = 8
vim.opt.softtabstop = 8
vim.opt.smarttab = true
vim.opt.completeopt = "menu,menuone,noselect"
vim.g.mapleader = " "

local key = vim.keymap.set

-- FIXED KEYMAPS: Added standard key combinations instead of empty quotes
key("i", "jk", "<Esc>", { desc = "Exit insert mode with jk" })
key("n", "<Space>", "za", { desc = "Toggle code folding with Spacebar" })
key("v", "<C-c>", ":w !xclip -i -sel c<CR>", { desc = "Copy selection to system clipboard" })

-- CodeCompanion Keymaps
key({ "n", "v" }, "<leader>ca", "<cmd>CodeCompanionActions<CR>", { desc = "AI Actions Menu" })
key({ "n", "v" }, "<leader>cc", "<cmd>CodeCompanionChat Toggle<CR>", { desc = "Toggle AI Chat" })
key("v", "<leader>cb", "<cmd>CodeCompanionChat Add<CR>", { desc = "Add selection to AI Chat" })
key("n", "<leader>cy", ":%y+<CR>", { desc = "Copy AI chat buffer to system clipboard" })
vim.cmd([[cabbrev cc CodeCompanion]])

-- Project Compiling & Execution Shortcuts (Fixed LHS)
key("n", "<F5>", ":!qmake && make && make clean && rm -f Makefile<CR>", { desc = "Build project with qmake" })
key("n", "<F6>", ":!./Calculo<CR>", { desc = "Run Calculo executable" })
key("n", "<leader>n", ":NERDTreeToggle<CR>:set relativenumber<CR>", { desc = "Toggle NERDTree" })

-- Custom Tabs for Rust
local rust_tabs = vim.api.nvim_create_augroup("RustTabs", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
    pattern = "rust",
    group = rust_tabs,
    callback = function()
        vim.opt_local.expandtab = false
        vim.opt_local.tabstop = 8
        vim.opt_local.shiftwidth = 8
        vim.opt_local.softtabstop = 8
    end,
})

-- ========================================================================== --
-- ==                          PLUGIN MANAGEMENT                           == --
-- ========================================================================== --
require("lazy").setup({
  { "neovim/nvim-lspconfig" }, -- Required for the underlying configs

  -- Force Mason to strictly use pnpm as its package manager provider
  {
    "williamboman/mason.nvim",
    opts = {
      providers = {
        "mason.providers.client.pnpm",
      },
    },
  },

  {
    "williamboman/mason-lspconfig.nvim",
    opts = {
      ensure_installed = { "clangd", "rust_analyzer", "jdtls" }
    }
  },

  { 'saghen/blink.cmp', version = '*', 
	  opts = { 
		  keymap = { preset = 'super-tab' } 
	  } 
  },
  { "preservim/nerdtree" },
  { "jiangmiao/auto-pairs" },
  { "rust-lang/rust.vim" },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },

  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("codecompanion").setup({
	strategies = {
	  chat = { adapter = "gemini" },
	  inline = { adapter = "gemini" },
	  agent = { adapter = "gemini" },
	},
        display = {
          chat = {
            window = {
              layout = "vertical",
              width = 0.35,  -- 35% of screen width; adjust to taste
              height = 0.8,
            },
          },
        },
        adapters = {
          gemini = function()
            return require("codecompanion.adapters").extend("gemini", {
              env = {
                api_key = "GEMINI_API_KEY",
              },
              schema = {
                model = {
                  default = "gemini-2.5-flash",
                },
              },
            })
          end,
        },
      })
    end,
  },
})

-- ========================================================================== --
-- ==                              LSP CONFIG                              == --
-- ========================================================================== --
if vim.lsp.config then
    -- Modern 0.11+ way
    vim.lsp.enable('clangd')
    vim.lsp.enable('rust_analyzer')
    vim.lsp.enable('ts_ls')
    vim.lsp.enable('jdtls')
else
    -- Fallback for 0.10 stable
    local lspconfig = require('lspconfig')
    lspconfig.clangd.setup({})
    lspconfig.rust_analyzer.setup({})
    lspconfig.ts_ls.setup({})
    lspconfig.jdtls.setup({})
end

-- Keybindings that only activate when an LSP is connected
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local opts = { buffer = args.buf }

    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', 'ge', vim.diagnostic.open_float)
  end,
})

-- Yank contents of nearest markdown code block (no fences)
key("n", "<leader>cy", function()
  local start_line = nil
  local cur = vim.fn.line(".")
  for i = cur, 1, -1 do
    if vim.fn.getline(i):match("^```") then
      start_line = i
      break
    end
  end
  local end_line = nil
  if start_line then
    for i = start_line + 1, vim.fn.line("$") do
      if vim.fn.getline(i):match("^```") then
        end_line = i
        break
      end
    end
  end
  if start_line and end_line then
    local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line - 1, false)
    vim.fn.setreg("+", table.concat(lines, "\n"))
    print("Code block yanked!")
  else
    print("No code block found.")
  end
end, { desc = "Yank nearest code block to clipboard" })

-- ========================================================================== --
-- ==                              APPEARANCE                              == --
-- ========================================================================== --
vim.cmd.colorscheme "catppuccin"
