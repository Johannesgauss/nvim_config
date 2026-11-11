local M = {}
local cc_buf = nil

function M.resize(target_percent)
  if vim.api.nvim_get_current_buf() ~= cc_buf then
    vim.notify("Cursor must be inside the Claude Code panel to resize!", vim.log.levels.WARN)
    return
  end
  local total_cols = vim.o.columns
  vim.cmd("vertical resize " .. math.floor(total_cols * target_percent))
end

function M.toggle()
  local slim_width = math.floor(vim.o.columns * 0.25)
  if cc_buf and vim.api.nvim_buf_is_valid(cc_buf) and vim.b[cc_buf].terminal_job_id then
    local win = vim.fn.bufwinnr(cc_buf)
    if win ~= -1 then
      vim.cmd(win .. "wincmd w")
      vim.cmd("hide")
    else
      vim.cmd("belowright " .. slim_width .. "vsplit")
      vim.cmd("buffer " .. cc_buf)
      vim.opt_local.winfixwidth = true
      vim.cmd("startinsert")
    end
  else
    vim.cmd("belowright " .. slim_width .. "vsplit")
    vim.cmd("terminal claude")
    cc_buf = vim.api.nvim_get_current_buf()
    vim.opt_local.winfixwidth = true
    vim.cmd("startinsert")
  end
end

M.specs = {
  {
    "claudecode",
    virtual = true,
    config = function()
      vim.keymap.set("n", "<leader>ci", M.toggle, { desc = "Toggle Claude Code Panel" })
      vim.keymap.set({ "n", "t" }, "<leader>cs", function() M.resize(0.25) end)
      vim.keymap.set({ "n", "t" }, "<leader>ce", function() M.resize(0.65) end)
      vim.keymap.set({ "n", "t" }, "<leader>ct", function() M.resize(1.00) end)
    end,
  },
}

return M
