-- ~/.config/nvim/lua/plugins/diffview.lua
return {
  "sindrets/diffview.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- For file icons
  },
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewFileHistory",
  },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
    { "<leader>gc", "<cmd>DiffviewClose<cr>", desc = "Close Diffview" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Current file history" },
    { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Git history" },
  },
  config = function()
    require("diffview").setup({
      enhanced_diff_hl = true,
      watch_index = true, -- Automatically refresh when index changes
      hooks = {
        diff_buf_read = function(bufnr)
          -- Custom options for diff buffers
          vim.opt_local.wrap = false
        end,
      },
      keymaps = {
        view = {
          { { "n", "v" }, "s", function()
            -- Stage current hunk or visual selection (git add)
            local mode = vim.api.nvim_get_mode().mode
            local is_visual = mode:match("[vV]")
            
            -- If in visual mode, exit to update marks '< and '>
            if is_visual then
              vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, false, true), "x", false)
            end
            
            vim.schedule(function()
              local cur_buf = vim.api.nvim_get_current_buf()
              local cur_buf_name = vim.api.nvim_buf_get_name(cur_buf)
              local is_index_buf = cur_buf_name:match("^diffview://")
              
              if is_index_buf then
                -- If we are in the index buffer, we get changes from the working tree
                if is_visual then
                  vim.cmd("silent! '<,'>diffget")
                else
                  vim.cmd("silent! diffget")
                end
                vim.cmd("silent! write")
              else
                -- If we are in the working tree buffer, we push changes to the index
                if is_visual then
                  vim.cmd("silent! '<,'>diffput")
                else
                  vim.cmd("silent! diffput")
                end
                
                -- Save the index buffer to apply the changes to git index
                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                  if vim.api.nvim_buf_is_loaded(buf) then
                    local name = vim.api.nvim_buf_get_name(buf)
                    if name:match("^diffview://") and vim.bo[buf].modified then
                      vim.api.nvim_buf_call(buf, function()
                        vim.cmd("silent! write")
                      end)
                    end
                  end
                end
              end
              
              vim.cmd("DiffviewRefresh")
            end)
          end, { desc = "Stage hunk or visual selection (git add)" } },
        },
      },
    })
  end,
}
