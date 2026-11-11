return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  ft = { "markdown" },
  opts = {
    heading = {
      enabled = true,
      sign = true,
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
    },
    code = {
      enabled = true,
      sign = false,
      style = "full",
      border = "thin",
    },
    bullet = {
      enabled = true,
      icons = { "●", "○", "◆", "◇" },
    },
    checkbox = {
      enabled = true,
    },
    anti_conceal = {
      enabled = false,
    },
    win_options = {
      conceallevel = {
        default = 2,
        rendered = 2,
      },
      concealcursor = {
        default = "nc",
        rendered = "nc",
      },
    },
    latex = {
      enabled = false,
    },
    pipe_table = {
      enabled = true,
      style = "full",
      border = {
        "┌", "┬", "┐",
        "├", "┼", "┤",
        "└", "┴", "┘",
        "│", "─",
      },
    },
    callout = {
      note = { raw = "[!NOTE]", rendered = "󰋽 Note", highlight = "RenderMarkdownInfo" },
      tip = { raw = "[!TIP]", rendered = "󰌶 Tip", highlight = "RenderMarkdownSuccess" },
      important = { raw = "[!IMPORTANT]", rendered = "󰅾 Important", highlight = "RenderMarkdownHint" },
      warning = { raw = "[!WARNING]", rendered = "󰀪 Warning", highlight = "RenderMarkdownWarn" },
      caution = { raw = "[!CAUTION]", rendered = "󰳦 Caution", highlight = "RenderMarkdownError" },
    },
  },
  config = function(_, opts)
    if vim.g.tty_mode then
      opts.heading = vim.tbl_deep_extend("force", opts.heading or {}, {
        icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " },
      })
      opts.bullet = vim.tbl_deep_extend("force", opts.bullet or {}, {
        icons = { "*", "-", "+", "*" },
      })
      opts.pipe_table = vim.tbl_deep_extend("force", opts.pipe_table or {}, {
        border = {
          "+", "+", "+",
          "+", "+", "+",
          "+", "+", "+",
          "|", "-",
        },
      })
      opts.callout = {
        note = { raw = "[!NOTE]", rendered = "[NOTE]", highlight = "RenderMarkdownInfo" },
        tip = { raw = "[!TIP]", rendered = "[TIP]", highlight = "RenderMarkdownSuccess" },
        important = { raw = "[!IMPORTANT]", rendered = "[IMPORTANT]", highlight = "RenderMarkdownHint" },
        warning = { raw = "[!WARNING]", rendered = "[WARNING]", highlight = "RenderMarkdownWarn" },
        caution = { raw = "[!CAUTION]", rendered = "[CAUTION]", highlight = "RenderMarkdownError" },
      }
    end

    local rm = require("render-markdown")
    rm.setup(opts)

    vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown toggle<CR>", {
      desc = "Toggle inline visual Markdown rendering",
    })
  end,
}
