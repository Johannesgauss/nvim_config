local M = {}

local models = { "qwen2.5-coder:1.5b", "qwen2.5-coder:7b" }
local current = 1

function M.complete()
  local ok, minuet = pcall(require, "minuet")
  if ok and minuet.complete then
    minuet.complete()
  end
end

function M.swap_model()
  current = (current == 1) and 2 or 1
  local ok, minuet = pcall(require, "minuet")
  if ok and minuet.setup then
    minuet.setup({
      provider = "openai_compatible",
      provider_options = {
        openai_compatible = {
          model = models[current],
          end_point = "http://127.0.0.1:11434/v1/completions",
          name = "Ollama",
          stream = true,
          optional = {
            max_tokens = 256,
            top_p = 0.9,
          },
        },
      },
    })
    vim.notify("Autocomplete model: " .. models[current], vim.log.levels.INFO)
  end
end

M.setup = function()
end

return M
