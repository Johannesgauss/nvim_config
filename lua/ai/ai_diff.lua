-- ============================================================================
-- AI vs Human Edit Attribution & Segment-by-Segment Approval
-- ============================================================================
-- Gated by `ai_diff = true/false` in features.conf.
-- Tracks human-saved buffer baselines separately from external disk edits
-- (e.g. written by `agy`), marks AI-changed lines with extmarks, and provides
-- segment-by-segment navigation, accept, and reject actions.
-- ============================================================================

local M = {}

local ns = vim.api.nvim_create_namespace("ai_diff_attribution")
local enabled = false
local reload_timer = nil

-- Per-buffer state:
-- last_disk_lines[buf] = string[] (lines as last read from or written to disk by Neovim)
-- segments[buf] = { { id = extmark_id, kind = "change"|"delete", old_lines = string[], after_anchor = bool } }
local last_disk_lines = {}
local segments = {}

local function apply_highlights()
  if vim.o.termguicolors then
    vim.api.nvim_set_hl(0, "AiDiffSign", { fg = "#89dceb", bold = true })
    vim.api.nvim_set_hl(0, "AiDiffLine", { bg = "#25263a" })
    vim.api.nvim_set_hl(0, "AiDiffDeleteVirt", { fg = "#f38ba8", italic = true })
  else
    vim.api.nvim_set_hl(0, "AiDiffSign", { ctermfg = 14, bold = true })
    vim.api.nvim_set_hl(0, "AiDiffLine", { ctermbg = 235 })
    vim.api.nvim_set_hl(0, "AiDiffDeleteVirt", { ctermfg = 9, italic = true })
  end
end

local function resolve_buf(buf)
  if not buf or buf == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return buf
end

local function is_trackable_buf(buf)
  buf = resolve_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if vim.bo[buf].buftype ~= "" then
    return false
  end
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= "" and not name:match("^diffview://")
end

local function to_diff_str(lines)
  if not lines or #lines == 0 then
    return ""
  end
  return table.concat(lines, "\n") .. "\n"
end

local function slice_lines(lines, start_1based, count)
  local out = {}
  for i = start_1based, start_1based + count - 1 do
    table.insert(out, lines[i] or "")
  end
  return out
end

local function record_baseline(buf)
  buf = resolve_buf(buf)
  if is_trackable_buf(buf) then
    last_disk_lines[buf] = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end
end

local function clear_buf_segments(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
  segments[buf] = nil
end

local function get_segment_range(buf, seg)
  local mark = vim.api.nvim_buf_get_extmark_by_id(buf, ns, seg.id, { details = true })
  if not mark or #mark == 0 then
    return nil
  end
  local row = mark[1]
  local details = mark[3] or {}
  if seg.kind == "delete" then
    local insert_at = seg.after_anchor and (row + 1) or row
    return row, insert_at, insert_at
  end
  local end_row = details.end_row or (row + 1)
  if end_row <= row then
    end_row = row + 1
  end
  return row, row, end_row
end

local function sorted_segments(buf)
  local list = segments[buf]
  if not list or #list == 0 then
    return {}
  end
  local valid = {}
  for _, seg in ipairs(list) do
    local anchor, start_row, end_row = get_segment_range(buf, seg)
    if anchor then
      table.insert(valid, {
        seg = seg,
        anchor = anchor,
        start_row = start_row,
        end_row = end_row,
      })
    end
  end
  table.sort(valid, function(a, b)
    return a.anchor < b.anchor
  end)
  return valid
end

local function remove_segment(buf, target_seg)
  pcall(vim.api.nvim_buf_del_extmark, buf, ns, target_seg.id)
  local list = segments[buf]
  if not list then
    return
  end
  for i, seg in ipairs(list) do
    if seg.id == target_seg.id then
      table.remove(list, i)
      break
    end
  end
  if #list == 0 then
    segments[buf] = nil
  end
end

local function add_ai_hunk(buf, old_lines, start_a, count_a, start_b, count_b, line_count)
  segments[buf] = segments[buf] or {}
  local old_slice = slice_lines(old_lines, start_a, count_a)

  if count_b > 0 then
    local start_row = math.max(0, start_b - 1)
    local end_row = math.min(line_count, start_row + count_b)
    local ext_opts = {
      sign_text = "AI",
      sign_hl_group = "AiDiffSign",
      line_hl_group = "AiDiffLine",
      right_gravity = true,
      end_right_gravity = true,
    }
    if end_row < line_count then
      ext_opts.end_row = end_row
      ext_opts.end_col = 0
    else
      ext_opts.end_row = math.max(start_row, line_count - 1)
      local last_line = vim.api.nvim_buf_get_lines(buf, ext_opts.end_row, ext_opts.end_row + 1, false)[1] or ""
      ext_opts.end_col = #last_line
    end
    local id = vim.api.nvim_buf_set_extmark(buf, ns, start_row, 0, ext_opts)
    table.insert(segments[buf], {
      id = id,
      kind = "change",
      old_lines = old_slice,
    })
  elseif count_a > 0 then
    -- Pure deletion: anchor extmark at surrounding line
    local after_anchor = start_b > 0
    local anchor_row = after_anchor and math.min(math.max(0, line_count - 1), start_b - 1) or 0
    local id = vim.api.nvim_buf_set_extmark(buf, ns, anchor_row, 0, {
      sign_text = "A-",
      sign_hl_group = "AiDiffSign",
      virt_text = { { string.format(" [AI deleted %d line%s]", count_a, count_a == 1 and "" or "s"), "AiDiffDeleteVirt" } },
      virt_text_pos = "eol",
      right_gravity = true,
    })
    table.insert(segments[buf], {
      id = id,
      kind = "delete",
      old_lines = old_slice,
      after_anchor = after_anchor,
    })
  end
end

local function on_external_reload(buf)
  if not is_trackable_buf(buf) then
    return
  end
  local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local old_lines = last_disk_lines[buf]
  last_disk_lines[buf] = new_lines

  if not old_lines then
    return
  end

  local hunks = vim.diff(to_diff_str(old_lines), to_diff_str(new_lines), {
    result_type = "indices",
  })

  if not hunks or #hunks == 0 then
    return
  end

  for _, h in ipairs(hunks) do
    add_ai_hunk(buf, old_lines, h[1], h[2], h[3], h[4], #new_lines)
  end

  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
  vim.notify(string.format("AI updated %s (%d segment%s)", name, #hunks, #hunks == 1 and "" or "s"), vim.log.levels.INFO)
end

local function safe_checktime()
  if vim.fn.mode() ~= "c" then
    pcall(vim.cmd, "silent! checktime")
  end
end

function M.stop_watcher()
  if reload_timer then
    pcall(reload_timer.stop, reload_timer)
    pcall(reload_timer.close, reload_timer)
    reload_timer = nil
  end
end

function M.start_watcher(is_running_fn)
  if not enabled then
    return
  end
  M.stop_watcher()
  local uv = vim.uv or vim.loop
  if not uv or not uv.new_timer then
    return
  end
  reload_timer = uv.new_timer()
  reload_timer:start(1000, 1000, vim.schedule_wrap(function()
    if type(is_running_fn) == "function" and not is_running_fn() then
      M.stop_watcher()
      return
    end
    safe_checktime()
  end))
end

local function find_segment_at_cursor(buf)
  local cur_row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local items = sorted_segments(buf)
  for _, item in ipairs(items) do
    if item.seg.kind == "delete" then
      if cur_row == item.anchor then
        return item
      end
    else
      if cur_row >= item.start_row and cur_row < item.end_row then
        return item
      end
    end
  end
  return nil
end

function M.next_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local items = sorted_segments(buf)
  if #items == 0 then
    vim.notify("No AI-edited segments in this buffer", vim.log.levels.INFO)
    return
  end
  local cur_row = vim.api.nvim_win_get_cursor(0)[1] - 1
  for _, item in ipairs(items) do
    if item.anchor > cur_row then
      vim.api.nvim_win_set_cursor(0, { item.anchor + 1, 0 })
      return
    end
  end
  vim.api.nvim_win_set_cursor(0, { items[1].anchor + 1, 0 })
end

function M.prev_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local items = sorted_segments(buf)
  if #items == 0 then
    vim.notify("No AI-edited segments in this buffer", vim.log.levels.INFO)
    return
  end
  local cur_row = vim.api.nvim_win_get_cursor(0)[1] - 1
  for i = #items, 1, -1 do
    if items[i].anchor < cur_row then
      vim.api.nvim_win_set_cursor(0, { items[i].anchor + 1, 0 })
      return
    end
  end
  vim.api.nvim_win_set_cursor(0, { items[#items].anchor + 1, 0 })
end

function M.accept_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local item = find_segment_at_cursor(buf)
  if not item then
    vim.notify("Cursor is not on an AI-edited segment", vim.log.levels.WARN)
    return
  end
  remove_segment(buf, item.seg)
  vim.notify("Accepted AI segment", vim.log.levels.INFO)
end

local function apply_reject(buf, item)
  local seg = item.seg
  if seg.kind == "delete" then
    local insert_at = math.min(item.start_row, vim.api.nvim_buf_line_count(buf))
    vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, seg.old_lines)
  else
    local line_count = vim.api.nvim_buf_line_count(buf)
    local start_row = math.min(item.start_row, line_count)
    local end_row = math.min(item.end_row, line_count)
    vim.api.nvim_buf_set_lines(buf, start_row, end_row, false, seg.old_lines)
  end
  remove_segment(buf, seg)
end

function M.reject_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local item = find_segment_at_cursor(buf)
  if not item then
    vim.notify("Cursor is not on an AI-edited segment", vim.log.levels.WARN)
    return
  end
  apply_reject(buf, item)
  vim.notify("Rejected AI segment (reverted)", vim.log.levels.INFO)
end

function M.accept_all()
  local buf = vim.api.nvim_get_current_buf()
  local count = segments[buf] and #segments[buf] or 0
  clear_buf_segments(buf)
  vim.notify(string.format("Accepted %d AI segment%s", count, count == 1 and "" or "s"), vim.log.levels.INFO)
end

function M.reject_all()
  local buf = vim.api.nvim_get_current_buf()
  local items = sorted_segments(buf)
  if #items == 0 then
    vim.notify("No AI-edited segments in this buffer", vim.log.levels.INFO)
    return
  end
  for i = #items, 1, -1 do
    apply_reject(buf, items[i])
  end
  vim.notify(string.format("Rejected %d AI segment%s", #items, #items == 1 and "" or "s"), vim.log.levels.INFO)
end

-- Exposed for testing and diagnostics
function M._record_baseline(buf)
  record_baseline(buf)
end

function M._on_external_reload(buf)
  on_external_reload(buf)
end

function M._get_segments(buf)
  return sorted_segments(resolve_buf(buf))
end

function M.setup()
  if enabled then
    return
  end
  enabled = true
  vim.o.autoread = true
  apply_highlights()

  local group = vim.api.nvim_create_augroup("AiDiffAttribution", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = apply_highlights,
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(args)
      local buf = resolve_buf(args.buf)
      if last_disk_lines[buf] == nil then
        record_baseline(buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      record_baseline(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      last_disk_lines[args.buf] = nil
      segments[args.buf] = nil
    end,
  })

  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermLeave" }, {
    group = group,
    callback = safe_checktime,
  })

  vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = group,
    callback = function(args)
      on_external_reload(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = M.stop_watcher,
  })

  -- Record baseline for any buffers already loaded before setup()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      record_baseline(buf)
    end
  end
end

return M
