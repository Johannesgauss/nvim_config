return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  cmd = { "TSUpdate", "TSInstall", "TSUninstall", "TSLog" },
  config = function()
    local ok_ts, ts = pcall(require, "nvim-treesitter")
    if ok_ts and type(ts.setup) == "function" then
      ts.setup({})

      local ensure_installed = { "prisma", "lua", "vim", "vimdoc", "markdown", "markdown_inline", "rust" }
      if vim.fn.executable("tree-sitter") == 1 then
        table.insert(ensure_installed, "latex")
      end

      if type(ts.install) == "function" then
        local installed = {}
        if type(ts.get_installed) == "function" then
          for _, lang in ipairs(ts.get_installed()) do
            installed[lang] = true
          end
        end
        local missing = vim.tbl_filter(function(lang)
          return not installed[lang]
        end, ensure_installed)
        if #missing > 0 then
          pcall(ts.install, missing)
        end
      end
    end

    -- Enable Neovim's native treesitter highlighting for any buffer with an installed parser
    local group = vim.api.nvim_create_augroup("UserTreesitterStart", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(ev)
        pcall(vim.treesitter.start, ev.buf)
      end,
    })

    -- Also start on the current buffer if already loaded before this config ran
    pcall(vim.treesitter.start)
  end,
}
