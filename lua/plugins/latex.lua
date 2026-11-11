local function get_math_at_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_row, cur_col = cursor[1] - 1, cursor[2]

  -- 1. Try Treesitter mathzones (accurate for single & multiline math in Markdown & TeX)
  local ok_utils, utils = pcall(require, "nabla.utils")
  if ok_utils and utils.get_all_mathzones then
    local zones = utils.get_all_mathzones()
    for _, node in ipairs(zones) do
      local srow, scol, erow, ecol = vim.treesitter.get_node_range(node)
      if (cur_row > srow or (cur_row == srow and cur_col >= scol)) and
         (cur_row < erow or (cur_row == erow and cur_col <= ecol)) then
        local texts = vim.api.nvim_buf_get_text(0, srow, scol, erow, ecol, {})
        local line = table.concat(texts, " ")
        line = line:gsub("[%s]", " ")
        line = line:gsub("[%$]", "")
        line = line:gsub("\\%[", "")
        line = line:gsub("\\%]", "")
        line = line:gsub("^\\%(", "")
        line = line:gsub("\\%)$", "")
        line = vim.trim(line)
        if line ~= "" then
          return line
        end
      end
    end
  end

  local cur_line = vim.api.nvim_get_current_line()

  -- 2. Check for single-line $$ ... $$
  local s1, e1, inner1 = cur_line:find("%$%$([^%$]+)%$%$")
  if s1 and cur_col >= (s1 - 1) and cur_col <= e1 then
    return inner1
  end

  -- 3. Check for inline $ ... $
  local pos = 1
  while true do
    local s, e, inner = cur_line:find("%$([^%$]+)%$", pos)
    if not s then break end
    if cur_col >= (s - 1) and cur_col <= e then
      return inner
    end
    pos = e + 1
  end

  -- 4. Check LaTeX environments: \begin{...} ... \end{...}
  local total_lines = vim.api.nvim_buf_line_count(0)
  local env_start, env_end
  for r = cur_row, 0, -1 do
    local l = vim.api.nvim_buf_get_lines(0, r, r + 1, false)[1] or ""
    if l:find("\\begin%{[^%}]+%}") then
      env_start = r
      break
    end
  end
  if env_start then
    for r = cur_row, total_lines - 1 do
      local l = vim.api.nvim_buf_get_lines(0, r, r + 1, false)[1] or ""
      if l:find("\\end%{[^%}]+%}") then
        env_end = r
        break
      end
    end
  end
  if env_start and env_end then
    local block_lines = vim.api.nvim_buf_get_lines(0, env_start, env_end + 1, false)
    local joined = table.concat(block_lines, " ")
    joined = joined:gsub("[%$]", "")
    return vim.trim(joined)
  end

  -- 5. Check for multi-line $$ ... $$ block
  local start_row, end_row
  for r = cur_row, 0, -1 do
    local l = vim.api.nvim_buf_get_lines(0, r, r + 1, false)[1] or ""
    if l:find("%$%$") then
      start_row = r
      break
    end
  end
  if start_row then
    for r = cur_row, total_lines - 1 do
      local l = vim.api.nvim_buf_get_lines(0, r, r + 1, false)[1] or ""
      if r ~= start_row and l:find("%$%$") then
        end_row = r
        break
      end
    end
  end
  if start_row and end_row then
    local block_lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
    local joined = table.concat(block_lines, " ")
    joined = joined:gsub("[%$]", "")
    return vim.trim(joined)
  end

  -- 6. Fallback: if current line contains math commands
  if cur_line:find("\\[a-zA-Z]+") or cur_line:find("[%^%_%{%}]") then
    return cur_line:gsub("^%s*%$*", ""):gsub("%$*%s*$", "")
  end

  return nil
end

local function preview_math_popup()
  local math_expr = get_math_at_cursor()
  if not math_expr or vim.trim(math_expr) == "" then
    -- Fallback to nabla's internal detection if available
    local ok_nabla, nabla = pcall(require, "nabla")
    if ok_nabla and nabla.popup then
      local ok = pcall(nabla.popup, { border = "rounded" })
      if ok then return end
    end
    vim.notify("No LaTeX formula found under cursor", vim.log.levels.WARN)
    return
  end

  math_expr = vim.trim(math_expr)
  local ok_parser, parser = pcall(require, "nabla.latex")
  local ok_ascii, ascii = pcall(require, "nabla.ascii")
  if not (ok_parser and ok_ascii) then
    vim.notify("Nabla module not found", vim.log.levels.ERROR)
    return
  end

  local succ_p, exp = pcall(parser.parse_all, math_expr)
  if not (succ_p and exp) then
    vim.notify("Unable to parse LaTeX formula: " .. tostring(exp), vim.log.levels.WARN)
    return
  end

  local succ_a, g = pcall(ascii.to_ascii, { exp }, 1)
  if not (succ_a and g and tostring(g) ~= "") then
    vim.notify("Error rendering 2D formula preview", vim.log.levels.WARN)
    return
  end

  local drawing = {}
  for row in vim.gsplit(tostring(g), "\n") do
    table.insert(drawing, row)
  end

  local floating_opts = {
    wrap = false,
    focusable = true,
    border = "rounded",
    stylize_markdown = false,
  }
  local bufnr_float, winr_float = vim.lsp.util.open_floating_preview(drawing, "markdown", floating_opts)
  if winr_float and vim.api.nvim_win_is_valid(winr_float) then
    vim.keymap.set("n", "q", function()
      pcall(vim.api.nvim_win_close, winr_float, true)
    end, { buffer = bufnr_float, silent = true, desc = "Close LaTeX preview" })
    vim.keymap.set("n", "<Esc>", function()
      pcall(vim.api.nvim_win_close, winr_float, true)
    end, { buffer = bufnr_float, silent = true, desc = "Close LaTeX preview" })
  end
end

local function toggle_nabla_virt()
  local nabla = require("nabla")
  nabla.toggle_virt()
  -- Nabla hardcodes concealcursor = "" which makes formulas disappear on cursor touch.
  -- Enforce concealcursor = "nc" so math remains cleanly rendered when navigating!
  local win = vim.api.nvim_get_current_win()
  if nabla.is_virt_enabled() then
    vim.wo[win].conceallevel = 2
    vim.wo[win].concealcursor = "nc"
  end
end

return {
  -- 1. In-buffer 2D LaTeX math formula renderer (works in Markdown, TeX, notes)
  {
    "jbyuki/nabla.nvim",
    cmd = { "NablaPopup", "NablaToggle" },
    keys = {
      {
        "<leader>lp",
        preview_math_popup,
        desc = "LaTeX: Display formula under cursor in 2D popup",
      },
      {
        "<leader>lv",
        toggle_nabla_virt,
        desc = "LaTeX: Toggle 2D virtual line formulas in buffer",
      },
      {
        "<leader>mp",
        preview_math_popup,
        desc = "Markdown/LaTeX: Display formula under cursor in 2D popup",
      },
    },
    config = function()
      vim.api.nvim_create_user_command("NablaPopup", preview_math_popup, {
        desc = "Display LaTeX formula in 2D popup under cursor",
      })

      vim.api.nvim_create_user_command("NablaToggle", toggle_nabla_virt, {
        desc = "Toggle 2D virtual LaTeX formulas",
      })
    end,
  },

  -- 2. Full LaTeX document authoring, compilation, and live preview suite
  {
    "lervag/vimtex",
    ft = { "tex", "plaintex", "bib" },
    init = function()
      vim.g.tex_flavor = "latex"
      vim.g.vimtex_view_method = "zathura"
      vim.g.vimtex_quickfix_mode = 0
      vim.g.tex_conceal = "abdmg"

      -- Enable compiler only if latexmk is present
      if vim.fn.executable("latexmk") == 0 then
        vim.g.vimtex_compiler_enabled = 0
      end

      -- Enable math concealment automatically in LaTeX buffers
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "tex", "plaintex" },
        callback = function()
          vim.opt_local.conceallevel = 2
          vim.opt_local.concealcursor = "nc"
        end,
      })
    end,
  },
}
