local M = {}

M.name = "docx"
M.plugins = {}

local docx_win = nil
local docx_buf = nil

--- Finds binary path for docxtui
local function get_docxtui_bin()
  local local_bin = vim.fn.expand("~/.local/bin/docxtui")
  if vim.fn.executable(local_bin) == 1 then
    return local_bin
  end
  local release_bin = vim.fn.expand("~/docxtui/target/release/docxtui")
  if vim.fn.executable(release_bin) == 1 then
    return release_bin
  end
  local project_bin = vim.fn.expand("~/docxtui/target/debug/docxtui")
  if vim.fn.executable(project_bin) == 1 then
    return project_bin
  end
  if vim.fn.executable("docxtui") == 1 then
    return "docxtui"
  end
  return nil
end

--- Finds the main working window (skipping trees or special buffers)
local function get_main_win()
  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_win_get_buf(cur_win)
  local ft = vim.bo[cur_buf].filetype
  local bt = vim.bo[cur_buf].buftype

  if ft ~= "NvimTree" and bt == "" then
    return cur_win
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local wft = vim.bo[buf].filetype
    local wbt = vim.bo[buf].buftype
    if wft ~= "NvimTree" and wbt == "" then
      return win
    end
  end

  -- If only NvimTree or special windows exist, open a new split to the right
  vim.cmd("rightbelow vsplit")
  return vim.api.nvim_get_current_win()
end

--- Opens a .docx file directly on the host terminal (bypassing libvterm for 100% native Kitty graphics)
function M.open_direct(filepath)
  local bin = get_docxtui_bin()
  if not bin then
    vim.notify("docxtui binary not found! Build it in ~/docxtui first.", vim.log.levels.ERROR)
    return
  end
  local target_file = filepath
  if not target_file or target_file == "" then
    local cur_buf_name = vim.api.nvim_buf_get_name(0)
    if cur_buf_name:match("%.docx$") then
      target_file = cur_buf_name
    else
      target_file = vim.fn.input("Docx file to open/create: ", "document.docx", "file")
      if target_file == "" then
        return
      end
    end
  end
  target_file = vim.fn.fnamemodify(target_file, ":p")
  vim.cmd("silent !" .. vim.fn.shellescape(bin) .. " " .. vim.fn.shellescape(target_file))
  vim.cmd("redraw!")
end

--- Opens a .docx file inside a native Neovim window split (like <C-j> or AI side panel)
function M.open_window(filepath, mode)
  local bin = get_docxtui_bin()
  if not bin then
    vim.notify("docxtui binary not found! Build it in ~/docxtui first.", vim.log.levels.ERROR)
    return
  end

  -- If docx window is already open, toggle it or switch to it
  if docx_win and vim.api.nvim_win_is_valid(docx_win) then
    vim.api.nvim_win_close(docx_win, true)
    docx_win = nil
    return
  end

  local target_file = filepath
  if not target_file or target_file == "" then
    local cur_buf_name = vim.api.nvim_buf_get_name(0)
    if cur_buf_name:match("%.docx$") then
      target_file = cur_buf_name
    else
      target_file = vim.fn.input("Docx file to open/create: ", "document.docx", "file")
      if target_file == "" then
        return
      end
    end
  end

  target_file = vim.fn.fnamemodify(target_file, ":p")

  local main_win = get_main_win()
  vim.api.nvim_set_current_win(main_win)

  -- Window placement:
  -- "full": replace current main buffer seamlessly
  -- "split": open like bottom terminal (<C-j>) or sidebar
  mode = mode or "full"

  local orig_buf = vim.api.nvim_get_current_buf()
  local is_docx_orig = vim.api.nvim_buf_get_name(orig_buf):match("%.docx$")

  if mode == "bottom" then
    local height = math.floor(vim.o.lines * 0.40)
    vim.cmd("belowright " .. height .. "split")
    docx_win = vim.api.nvim_get_current_win()
    vim.wo[docx_win].winfixheight = true
    vim.cmd("enew")
  elseif mode == "side" then
    local width = math.floor(vim.o.columns * 0.50)
    vim.cmd("belowright " .. width .. "vsplit")
    docx_win = vim.api.nvim_get_current_win()
    vim.wo[docx_win].winfixwidth = true
    vim.cmd("enew")
  else
    -- Full window: edit directly in the current window like a real document!
    vim.cmd("enew")
    docx_win = vim.api.nvim_get_current_win()
    vim.wo[docx_win].number = false
    vim.wo[docx_win].relativenumber = false
    vim.wo[docx_win].signcolumn = "no"
    vim.wo[docx_win].statusline = " "
    if is_docx_orig and orig_buf ~= vim.api.nvim_get_current_buf() then
      pcall(vim.api.nvim_buf_delete, orig_buf, { force = true })
    end
  end

  docx_buf = vim.api.nvim_get_current_buf()
  vim.b[docx_buf].is_docxtui = true
  vim.bo[docx_buf].scrollback = 1
  vim.opt_local.timeoutlen = 0

  -- Buffer-local passthrough for terminal mode: ensure 'j', 'k', and 'jk' pass with zero latency
  vim.keymap.set("t", "j", "j", { buffer = docx_buf, nowait = true })
  vim.keymap.set("t", "k", "k", { buffer = docx_buf, nowait = true })
  vim.keymap.set("t", "jk", "jk", { buffer = docx_buf, nowait = true })

  local pos_file = string.format("/tmp/docxtui_win_pos_%d", vim.fn.getpid())
  local function update_win_pos()
    if docx_win and vim.api.nvim_win_is_valid(docx_win) then
      local p = vim.api.nvim_win_get_position(docx_win)
      local r = p[1] + 1
      local c = p[2] + 1
      local w = vim.api.nvim_win_get_width(docx_win)
      local h = vim.api.nvim_win_get_height(docx_win)
      local f = io.open(pos_file, "w")
      if f then
        f:write(string.format("%d,%d,%d,%d\n", c, r, w, h))
        f:close()
      end
      return c, r, w, h
    end
    return 1, 1, 80, 24
  end

  -- Query exact window position relative to Neovim grid (leaving NvimTree untouched)
  local win_col, win_row, win_w, win_h = update_win_pos()

  -- Start docxtui inside native Neovim terminal with layout bounds
  local cmd = { bin, target_file }
  local job_id = vim.fn.termopen(cmd, {
    env = {
      NVIM_WIN_COL = tostring(win_col),
      NVIM_WIN_ROW = tostring(win_row),
      NVIM_WIN_WIDTH = tostring(win_w),
      NVIM_WIN_HEIGHT = tostring(win_h),
      NVIM_WIN_POS_FILE = pos_file,
    },
    on_exit = function()
      pcall(os.remove, pos_file)
      vim.schedule(function()
        if docx_win and vim.api.nvim_win_is_valid(docx_win) then
          if mode == "bottom" or mode == "side" then
            vim.api.nvim_win_close(docx_win, true)
          else
            if docx_buf and vim.api.nvim_buf_is_valid(docx_buf) then
              vim.api.nvim_buf_delete(docx_buf, { force = true })
            end
          end
        end
        docx_win = nil
        docx_buf = nil
      end)
    end,
  })

  -- Keep terminal in active job mode when switching from NvimTree or clicking window,
  -- and keep window coordinates synced if NvimTree toggles or splits resize.
  local buf_augroup = vim.api.nvim_create_augroup("DocxTuiBuffer_" .. docx_buf, { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = buf_augroup,
    buffer = docx_buf,
    callback = function()
      update_win_pos()
      vim.cmd("startinsert")
    end,
  })
  vim.api.nvim_create_autocmd({ "WinResized", "WinScrolled", "VimResized" }, {
    group = buf_augroup,
    callback = function()
      update_win_pos()
    end,
  })

  -- If user ever drops into Neovim Terminal-Normal mode (nt), forward keys & wheel straight to docxtui
  for _, key in ipairs({ "j", "k", "h", "l", "+", "-", "=", "0", "w", "q", "Z", "P", "i", "a", "n", "p", "J", "K" }) do
    vim.keymap.set("n", key, function()
      if job_id and job_id > 0 then
        pcall(vim.api.nvim_chan_send, job_id, key)
      end
      vim.cmd("startinsert")
    end, { buffer = docx_buf, nowait = true, silent = true })
  end
  vim.keymap.set("n", "<ScrollWheelUp>", function()
    if job_id and job_id > 0 then
      pcall(vim.api.nvim_chan_send, job_id, "k")
    end
    vim.cmd("startinsert")
  end, { buffer = docx_buf, nowait = true, silent = true })
  vim.keymap.set("n", "<ScrollWheelDown>", function()
    if job_id and job_id > 0 then
      pcall(vim.api.nvim_chan_send, job_id, "j")
    end
    vim.cmd("startinsert")
  end, { buffer = docx_buf, nowait = true, silent = true })

  vim.cmd("startinsert")
end

--- Auto-attach to .docx files when opened in Neovim
function M.setup()
  local augroup = vim.api.nvim_create_augroup("DocxTuiIntegration", { clear = true })

  -- When user does :e file.docx or nvim file.docx
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = augroup,
    pattern = "*.docx",
    callback = function(ev)
      local file = ev.file
      vim.bo[ev.buf].buftype = "nofile"
      vim.schedule(function()
        M.open_window(file, "full")
      end)
    end,
  })

  -- User commands
  vim.api.nvim_create_user_command("Docx", function(opts)
    local arg = opts.args ~= "" and opts.args or nil
    M.open_window(arg, "full")
  end, { nargs = "?", complete = "file", desc = "Open .docx file in docxtui full window" })

  vim.api.nvim_create_user_command("DocxDirect", function(opts)
    local arg = opts.args ~= "" and opts.args or nil
    M.open_direct(arg)
  end, { nargs = "?", complete = "file", desc = "Open .docx file directly on host terminal (clean Kitty graphics)" })

  vim.api.nvim_create_user_command("DocxSplit", function(opts)
    local arg = opts.args ~= "" and opts.args or nil
    M.open_window(arg, "bottom")
  end, { nargs = "?", complete = "file", desc = "Open .docx file in docxtui bottom split" })
end

M.actions = {
  ["docx:open"] = function()
    M.open_window(nil, "full")
  end,
}

return M
