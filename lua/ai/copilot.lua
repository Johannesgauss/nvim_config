local M = {}

-- Lazy plugin specs
M.specs = {
  {
    "zbirenbaum/copilot.lua",
    lazy = true,

config = function()
  require("copilot").setup({
    suggestion = {
      enabled = true,
      auto_trigger = true,
      debounce = 75,
      keymap = {
        next    = "<M-]>",
        prev    = "<M-[>",
        dismiss = "<M-x>",
      },
    },
    panel = { enabled = true },
    -- No filetypes block needed: lazy=true already prevents loading until CopilotStart
  })
end,


  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    name = "CopilotChat.nvim",
    lazy = true,
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    opts = {
      debug = false,
      show_help = true,
      window = { layout = "vertical", width = 0.4 },
      context = "buffer",  -- add this line
    },
  },
}

-- Runtime logic
M.setup = function()
  vim.api.nvim_create_user_command("CopilotStart", function()
    local safe_directories = {
      "/home/paulo/Documents/my_projects",
      "/home/paulo/Documents/UFBA",
    }

    local current_dir = vim.fn.getcwd() or ""
    local is_safe = false

    for _, dir in ipairs(safe_directories) do
      if current_dir:find(dir, 1, true) == 1 then
        is_safe = true
        break
      end
    end

    if not is_safe then
      vim.notify("Privacy Protection: Copilot blocked in this directory!", vim.log.levels.WARN)
      return
    end

    require("lazy").load({ plugins = { "copilot.lua", "CopilotChat.nvim" } })
    require("copilot.command").enable()

    vim.keymap.set({ "n", "v" }, "<leader>cc", function()
      require("CopilotChat").toggle()
    end, { desc = "CopilotChat: Toggle chat window" })

    vim.keymap.set("n", "<leader>cr", function()
      require("CopilotChat").reset()
    end, { desc = "CopilotChat: Clear conversation history" })

    local suggestion = require("copilot.suggestion")

    vim.keymap.set("i", "<C-e>", function()
      if suggestion.is_visible() then
        suggestion.accept()
      else
        return vim.api.nvim_replace_termcodes("<C-e>", true, true, true)
      end
    end, { expr = true, desc = "Copilot: Accept suggestion" })

    vim.keymap.set("i", "<M-.>", function()
      suggestion.next()
    end, { desc = "Copilot: Next suggestion" })

    vim.notify("✓ Copilot active in safe directory: " .. current_dir, vim.log.levels.INFO)
  end, {})
end

return M
