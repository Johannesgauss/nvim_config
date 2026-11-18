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
        view = (function()
          local function with_hunk_context(callback)
            local mode = vim.api.nvim_get_mode().mode
            local is_visual = mode:match("[vV]")

            -- If in visual mode, exit to update marks '< and '>
            if is_visual then
              vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, false, true), "x", false)
            end

            vim.schedule(function()
              local cur_buf = vim.api.nvim_get_current_buf()
              local cur_buf_name = vim.api.nvim_buf_get_name(cur_buf)
              local is_index_buf = cur_buf_name:match("^diffview://") ~= nil
              callback(is_visual, is_index_buf)
              vim.cmd("DiffviewRefresh")
            end)
          end

          local function save_matching_buffers(match_index)
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if vim.api.nvim_buf_is_loaded(buf) then
                local name = vim.api.nvim_buf_get_name(buf)
                local is_dv = name:match("^diffview://") ~= nil
                if is_dv == match_index and vim.bo[buf].modified then
                  vim.api.nvim_buf_call(buf, function()
                    vim.cmd("silent! write")
                  end)
                end
              end
            end
          end

          local function run_diff_cmd(cmd_name, is_visual)
            if is_visual then
              vim.cmd("silent! '<,'>" .. cmd_name)
            else
              vim.cmd("silent! " .. cmd_name)
            end
          end

          return {
            { { "n", "v" }, "s", function()
              with_hunk_context(function(is_visual, is_index_buf)
                if is_index_buf then
                  run_diff_cmd("diffget", is_visual)
                  vim.cmd("silent! write")
                else
                  run_diff_cmd("diffput", is_visual)
                  save_matching_buffers(true)
                end
              end)
            end, { desc = "Accept/stage hunk or visual selection (git add)" } },
            { { "n", "v" }, "x", function()
              with_hunk_context(function(is_visual, is_index_buf)
                if is_index_buf then
                  run_diff_cmd("diffput", is_visual)
                  save_matching_buffers(false)
                else
                  run_diff_cmd("diffget", is_visual)
                  vim.cmd("silent! write")
                end
              end)
            end, { desc = "Reject/discard hunk or visual selection" } },
            { "n", "]h", "]c", { desc = "Next diff segment" } },
            { "n", "[h", "[c", { desc = "Previous diff segment" } },
          }
        end)(),
      },
    })
  end,
}
