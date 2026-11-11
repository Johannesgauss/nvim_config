return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      cond = function()
        return vim.fn.executable("make") == 1
      end,
    },
    "nvim-tree/nvim-web-devicons",
  },
  cmd = "Telescope",
  opts = {
    defaults = {
      path_display = { "truncate" },
      sorting_strategy = "ascending",
      layout_config = {
        horizontal = {
          prompt_position = "top",
          preview_width = 0.55,
        },
      },
      mappings = {
        i = {
          ["<C-k>"] = function(...)
            return require("telescope.actions").move_selection_previous(...)
          end,
          ["<C-j>"] = function(...)
            return require("telescope.actions").move_selection_next(...)
          end,
        },
      },
    },
  },
  config = function(_, opts)
    local telescope = require("telescope")
    if vim.g.tty_mode then
      opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
        color_devicons = false,
        disable_devicons = true,
        prompt_prefix = "> ",
        selection_caret = "* ",
        borderchars = { "-", "|", "-", "|", "+", "+", "+", "+" },
      })
    end
    telescope.setup(opts)
    pcall(telescope.load_extension, "fzf")
  end,
}
