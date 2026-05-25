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
key("i", "jk", "<Esc>")
key("i", "<C-c>", "<Esc>")
key("n", "<leader>", "za")
key("v", "<C-a>", ":w !xclip -i -sel c<CR><CR>")

key({ "n", "v" }, "<leader>a", "<cmd>CodeCompanionActions<cr>", { desc = "AI Actions Menu" })
key({ "n", "v" }, "<leader>c", "<cmd>CodeCompanionChat Toggle<cr>", { desc = "Toggle AI Chat" })
vim.cmd([[cabbrev cc CodeCompanion]])

-- ANONYMOUS "ga": Sends code with language extension, hides file paths entirely
key("v", "ga", function()
  -- 1. Grab the current file extension (returns empty string if unnamed/no extension)
  local ext = vim.fn.expand("%:e")
  
  -- 2. Grab the visually selected text line-by-line
  vim.cmd('normal! "zy')
  local raw_text = vim.fn.getreg("z")
  local lines = vim.split(raw_text, "\n", { plain = true })
  
  -- 3. Wrap inside markdown code fences using the extracted extension
  table.insert(lines, 1, "```" .. ext)
  table.insert(lines, "```")

  -- 4. Get the active chat buffer if open, or toggle it open
  local chat = require("codecompanion").last_chat()
  if not chat then
    vim.cmd("CodeCompanionChat Toggle")
    chat = require("codecompanion").last_chat()
  end

  -- 5. Inject the code lines into the bottom of the AI chat window
  if chat and chat.bufnr then
    local last_line = vim.api.nvim_buf_line_count(chat.bufnr)
    -- Append a newline gap, then our code lines
    vim.api.nvim_buf_set_lines(chat.bufnr, last_line, last_line, false, vim.list_extend({ "" }, lines))
    print("Code block (" .. (ext ~= "" and ext or "plain text") .. ") added anonymously.")
  else
    print("Error: Could not find active AI chat buffer.")
  end

  -- 6. Clear register
  vim.fn.setreg("z", "")
end, { desc = "Add code selection with extension to AI Chat" })


key("n", "<C-A-b>", ":!qmake && make && make clean && rm -f Makefile<CR>")
key("n", "<C-A-r>", ":!./Calculo<CR>")
key("n", "<C-t>", ":NERDTreeToggle<CR>:set relativenumber<CR>")
vim.g.NERDTreeIgnore = { '\\.o$' }

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

-- Toggle a slim terminal at the bottom (VS Code style)
key("n", "<C-j>", function()
  local term_win = nil
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "terminal" then
      term_win = win
      break
    end
  end

  if term_win then
    vim.api.nvim_win_close(term_win, true)
  else
    vim.cmd("botright 8split | term")
    vim.cmd("startinsert")
  end
end, { desc = "Toggle VS Code style terminal" })

key("t", "jk", [[<C-\><C-n>]], { desc = "Exit terminal insert mode" })

vim.api.nvim_create_autocmd("TermClose", {
  callback = function()
    vim.cmd("bdelete")
  end,
})

-- ========================================================================== --
-- ==                          PLUGIN MANAGEMENT                           == --
-- ========================================================================== --
require("lazy").setup({
  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim", opts = {} },
  { "williamboman/mason-lspconfig.nvim", opts = { ensure_installed = { "clangd", "rust_analyzer", "jdtls" } } },
  { "saghen/blink.cmp", version = "*", opts = { keymap = { preset = "super-tab" } } },
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
    opts = {
      adapters = {
        http = {
          gemini = function()
            return require("codecompanion.adapters").extend("gemini", {
              env = {
                api_key = "GEMINI_API_KEY",
              },
              schema = {
                model = {
                  default = "gemini-2.5-flash",
                  choices = {
                    ["gemini-2.5-flash"] = { opts = { can_reason = false, has_vision = true } },
                  },
                },
              },
            })
          end,
        },
      },
      strategies = {
        chat   = { adapter = "gemini" },
        inline = { adapter = "gemini" },
        agent  = { adapter = "gemini" },
      },
      display = {
        chat = {
          window = {
            layout = "vertical",
            width = 0.25,
            height = 0.8,
          },
        },
      },
    },
  },
})

-- ========================================================================== --
-- ==                              LSP CONFIG                              == --
-- ========================================================================== --
if vim.lsp.config then
    vim.lsp.enable("clangd")
    vim.lsp.enable("rust_analyzer")
    vim.lsp.enable("jdtls")
else
    local lspconfig = require("lspconfig")
    lspconfig.clangd.setup({})
    lspconfig.rust_analyzer.setup({})
    lspconfig.jdtls.setup({})
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf }
    vim.keymap.set("n", "<C-k>", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "<C-s>", vim.lsp.buf.signature_help, opts)
    vim.keymap.set("n", "ge", vim.diagnostic.open_float)
  end,
})

-- Yank contents of nearest markdown code block (no fences)
key("n", "<leader>y", function()
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

