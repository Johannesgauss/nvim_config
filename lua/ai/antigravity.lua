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

local function is_agy_running()
  if not agy_buf or not vim.api.nvim_buf_is_valid(agy_buf) then
    return false
  end
  local job_id = vim.b[agy_buf].terminal_job_id
  if not job_id then
    return false
  end
  return vim.fn.jobwait({ job_id }, 0)[1] == -1
end

function M.toggle(cmd_args)
  local slim_width = math.floor(vim.o.columns * 0.25)
  if is_agy_running() then
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
    if agy_buf and vim.api.nvim_buf_is_valid(agy_buf) then
      pcall(vim.api.nvim_buf_delete, agy_buf, { force = true })
    end
    vim.cmd("belowright " .. slim_width .. "vsplit")
    local cmd = "terminal agy"
    if cmd_args and cmd_args ~= "" then
      cmd = cmd .. " " .. cmd_args
    end
    vim.cmd(cmd)
    agy_buf = vim.api.nvim_get_current_buf()
    vim.opt_local.winfixwidth = true
    if require("core.features").is_enabled("ai_diff") then
      local ai_diff = require("ai.ai_diff")
      ai_diff.start_watcher(is_agy_running)
      vim.api.nvim_create_autocmd("TermClose", {
        buffer = agy_buf,
        once = true,
        callback = function()
          ai_diff.stop_watcher()
          pcall(vim.cmd, "silent! checktime")
        end,
      })
    end
    vim.cmd("startinsert")
  end
end

function M.toggle_auto()
  M.toggle("--mode auto --dangerously-skip-permissions")
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
