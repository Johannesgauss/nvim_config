local M = {}

M.specs = {
  {
    "antigravity",
    virtual = true,
    config = function()
      local agy_buf = nil

      local function resize_agy_panel(target_percent)
        if vim.api.nvim_get_current_buf() ~= agy_buf then
          print("O cursor precisa estar no painel do Antigravity para redimensionar!")
          return
        end
        local total_cols = vim.o.columns
        vim.cmd("vertical resize " .. math.floor(total_cols * target_percent))
      end

      vim.keymap.set("n", "<leader>ai", function()
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
          vim.cmd("terminal agy -i")
          agy_buf = vim.api.nvim_get_current_buf()
          vim.opt_local.winfixwidth = true
          vim.cmd("startinsert")
        end
      end, { desc = "Toggle Antigravity CLI Panel" })

      vim.keymap.set("n", "<leader>as", function() resize_agy_panel(0.25) end)
      vim.keymap.set("t", "<leader>as", function() resize_agy_panel(0.25) end)
      vim.keymap.set("n", "<leader>ae", function() resize_agy_panel(0.65) end)
      vim.keymap.set("t", "<leader>ae", function() resize_agy_panel(0.65) end)
      vim.keymap.set("n", "<leader>at", function() resize_agy_panel(1.00) end)
      vim.keymap.set("t", "<leader>at", function() resize_agy_panel(1.00) end)
    end,
  },
}

return M
