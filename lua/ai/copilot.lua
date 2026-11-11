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

function M.toggle_chat()
  local ok, chat = pcall(require, "CopilotChat")
  if ok and chat.toggle then chat.toggle() end
end

function M.reset_chat()
  local ok, chat = pcall(require, "CopilotChat")
  if ok and chat.reset then chat.reset() end
end

function M.accept()
  local ok, suggestion = pcall(require, "copilot.suggestion")
  if ok and suggestion.is_visible() then
    suggestion.accept()
    return true
  end
  return false
end

function M.next()
  local ok, suggestion = pcall(require, "copilot.suggestion")
  if ok then suggestion.next() end
end

-- Runtime logic
M.setup = function()
  vim.api.nvim_create_user_command("CopilotStart", function()
    local safe_directories = {
      vim.fn.expand("~/projects"),
      vim.fn.expand("~/workspace"),
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

    vim.notify("✓ Copilot active in safe directory: " .. current_dir, vim.log.levels.INFO)
  end, {})
end

return M
