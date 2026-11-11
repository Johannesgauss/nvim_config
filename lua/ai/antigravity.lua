local M = {}
local agy_buf = nil

function M.resize(target_percent)
  if vim.api.nvim_get_current_buf() ~= agy_buf then
    vim.notify("Cursor must be inside the Antigravity panel to resize!", vim.log.levels.WARN)
    return
  end
  local total_cols = vim.o.columns
  vim.cmd("vertical resize " .. math.floor(total_cols * target_percent))
end

function M.toggle_diffview()
  local ok, diffview_lib = pcall(require, "diffview.lib")
  if not ok then
    vim.cmd("DiffviewOpen")
    return
  end
  if next(diffview_lib.views) == nil then
    vim.cmd("DiffviewOpen")
  else
    vim.cmd("DiffviewClose")
  end
end

function M.toggle()
  local slim_width = math.floor(vim.o.columns * 0.25)
  if agy_buf and vim.api.nvim_buf_is_valid(agy_buf) and vim.b[agy_buf].terminal_job_id then
    local win = vim.fn.bufwinnr(agy_buf)
    if win ~= -1 then
      vim.cmd(win .. "wincmd w")
      vim.cmd("hide")
    else
      vim.cmd("belowright " .. slim_width .. "vsplit")
      vim.cmd("buffer " .. agy_buf)
      vim.opt_local.winfixwidth = true
      vim.cmd("startinsert")
    end
  else
    vim.cmd("belowright " .. slim_width .. "vsplit")
    vim.cmd("terminal agy")
    agy_buf = vim.api.nvim_get_current_buf()
    vim.opt_local.winfixwidth = true
    vim.cmd("startinsert")
  end
end

M.specs = {
  {
    "antigravity",
    virtual = true,
    config = function()
    end,
  },
}

return M
