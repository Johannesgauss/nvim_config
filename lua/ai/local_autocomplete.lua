local M = {}

M.specs = {
  {
    "milanglacier/minuet-ai.nvim",
    lazy = true,
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("minuet").setup({
        provider = "openai_compatible",
        provider_options = {
          openai_compatible = {
            model = "qwen2.5-coder:7b",
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
    end,
  },
}

M.setup = function()
  -- Trigger local autocomplete manually with <leader>om
  vim.keymap.set("i", "<C-y>", function()
    require("minuet").complete()
  end, { desc = "Ollama: Trigger autocomplete" })
end

return M
