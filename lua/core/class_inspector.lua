local M = {}

--- Extracts documentation comments immediately preceding a member or inside a method (Python/JSDoc)
local function extract_member_doc(bufnr, lnum)
  local doc_lines = {}
  local in_jsdoc = false

  -- Check lines above for JSDoc /** ... */ or line comments (// or #)
  for l = lnum - 1, math.max(0, lnum - 8), -1 do
    local raw = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, false)[1] or ""
    local line = vim.trim(raw)
    if line:match("%*/$") then
      in_jsdoc = true
    end
    if in_jsdoc then
      local clean = line:gsub("^/%*%*%s*", ""):gsub("%s*%*/$", ""):gsub("^%*%s*", "")
      if clean ~= "" and not clean:match("^@") then
        table.insert(doc_lines, 1, clean)
      end
      if line:match("^/%*%*") then
        break
      end
    elseif line:match("^///?%s*(.*)") then
      local clean = line:match("^///?%s*(.*)")
      table.insert(doc_lines, 1, clean)
    elseif line:match("^#%s*(.*)") and not line:match("^#%s*include") then
      local clean = line:match("^#%s*(.*)")
      table.insert(doc_lines, 1, clean)
    else
      if #doc_lines > 0 or line == "" then
        break
      end
    end
  end

  if #doc_lines > 0 then
    return table.concat(doc_lines, " ")
  end

  -- Check next line for Python docstring """ ... """ or ''' ... '''
  local next_raw = vim.api.nvim_buf_get_lines(bufnr, lnum + 1, lnum + 2, false)[1] or ""
  local next_line = vim.trim(next_raw)
  if next_line:match('^"""') then
    return next_line:gsub('^"""%s*', ''):gsub('%s*"""$', '')
  elseif next_line:match("^'''") then
    return next_line:gsub("^'''%s*", ''):gsub("%s*'''$", '')
  end

  return ""
end

--- Formats a single member line (stripping trailing brackets, colons, semicolons)
local function format_member_sig(line_text, child_name)
  if not line_text or line_text == "" then
    return child_name
  end
  local clean = vim.trim(line_text)
  clean = clean:gsub("{%s*$", ""):gsub(";%s*$", ""):gsub(":%s*$", "")
  return clean
end

--- Recursively collects members, unpacking anonymous unions and structs
local function collect_members(bufnr, children, components, methods, indent_level, seen_sigs)
  seen_sigs = seen_sigs or {}
  indent_level = indent_level or 0

  for _, child in ipairs(children or {}) do
    local lnum = child.range.start.line
    local ltext = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or child.name
    local is_anon = child.name:match("^%(anonymous") or child.name:match("^<anonymous") or child.name == ""

    if is_anon and child.children and #child.children > 0 then
      local raw_clean = vim.trim(ltext):gsub("{%s*$", ""):gsub(";%s*$", "")
      if raw_clean == "" then raw_clean = "union / struct" end
      local prefix = string.rep("  ", indent_level)
      table.insert(components, {
        name = child.name,
        sig = prefix .. raw_clean .. ":",
        doc = "",
        is_header = true,
      })
      collect_members(bufnr, child.children, components, methods, indent_level + 1, seen_sigs)
    else
      local clean = format_member_sig(ltext, child.name)
      local sig_key = tostring(lnum) .. ":" .. clean
      if not seen_sigs[sig_key] then
        seen_sigs[sig_key] = true
        local prefix = string.rep("  ", indent_level)
        local sig = prefix .. clean
        local doc = extract_member_doc(bufnr, lnum)
        local entry = { name = child.name, sig = sig, doc = doc, lnum = lnum + 1 }
        -- Kinds: 6 = Method, 9 = Constructor
        if child.kind == 6 or child.kind == 9 then
          table.insert(methods, entry)
        else
          table.insert(components, entry)
        end
      end
    end
  end
end

--- Recursively finds the enclosing or targeted Class/Struct/Interface in document symbols
-- Prioritizes symbols that actually have children so that forward declarations don't shadow definitions.
function M.find_class_symbol(symbols, target_line, type_names)
  if type(type_names) == "string" then
    type_names = { type_names }
  end

  local candidate_with_children = nil
  local candidate_by_line = nil
  local candidate_any = nil

  local function search(sym_list)
    for _, sym in ipairs(sym_list or {}) do
      local is_class_kind = (sym.kind == 5 or sym.kind == 11 or sym.kind == 23)
      local in_line_range = target_line and (target_line >= sym.range.start.line and target_line <= sym.range["end"].line)
      local has_children = sym.children and #sym.children > 0

      local matches_name = false
      for _, tn in ipairs(type_names or {}) do
        if tn and tn ~= "" and (sym.name == tn or sym.name:match("^" .. vim.pesc(tn) .. "$")) then
          matches_name = true
          break
        end
      end

      if is_class_kind then
        if in_line_range and has_children then
          return sym
        elseif in_line_range and not candidate_by_line then
          candidate_by_line = sym
        end

        if matches_name and has_children and not candidate_with_children then
          candidate_with_children = sym
        elseif matches_name and not candidate_any then
          candidate_any = sym
        end
      end

      if sym.children and #sym.children > 0 then
        local found = search(sym.children)
        if found then return found end
      end
    end
    return nil
  end

  local direct = search(symbols)
  if direct then return direct end
  if candidate_with_children then return candidate_with_children end
  if candidate_by_line then return candidate_by_line end
  return candidate_any
end

--- Builds a markdown breakdown of the class components and methods
function M.format_class_details(bufnr, class_sym)
  local kind_labels = { [5] = "Class", [11] = "Interface", [23] = "Struct" }
  local kind_name = kind_labels[class_sym.kind] or "Class / Struct"

  local lines = {
    string.format("### %s `%s`", kind_name, class_sym.name),
  }

  local components = {}
  local methods = {}
  collect_members(bufnr, class_sym.children, components, methods, 0)

  if #components > 0 then
    table.insert(lines, "")
    table.insert(lines, "**Components & Fields:**")
    for _, c in ipairs(components) do
      if c.is_header then
        table.insert(lines, string.format("- `%s`", c.sig))
      else
        local desc_str = (c.doc ~= "") and (" — " .. c.doc) or ""
        table.insert(lines, string.format("- `%s`%s", c.sig, desc_str))
      end
    end
  end

  if #methods > 0 then
    table.insert(lines, "")
    table.insert(lines, "**Methods:**")
    for _, m in ipairs(methods) do
      local desc_str = (m.doc ~= "") and (" — " .. m.doc) or ""
      table.insert(lines, string.format("- `%s`%s", m.sig, desc_str))
    end
  end

  return lines
end

--- Extracts potential struct/class type names from hover markdown lines
function M.extract_types_from_hover(hover_lines)
  local names = {}
  local seen = {}
  local function add(n)
    if n and n ~= "" and not seen[n] then
      seen[n] = true
      table.insert(names, n)
    end
  end

  for _, line in ipairs(hover_lines or {}) do
    -- e.g. "aka struct Stmt" or "aka class Foo"
    local aka_st = line:match("aka%s+struct%s+([%w_]+)")
    if aka_st then add(aka_st) end
    local aka_cl = line:match("aka%s+class%s+([%w_]+)")
    if aka_cl then add(aka_cl) end

    -- e.g. "Type: `struct Stmt`" or "Type: struct Stmt"
    local t1 = line:match("Type:%s*`?struct%s+([%w_]+)")
    if t1 then add(t1) end
    local t2 = line:match("Type:%s*`?class%s+([%w_]+)")
    if t2 then add(t2) end

    -- e.g. "Type: `Stmt *`" or "Type: Stmt *"
    local t_base = line:match("Type:%s*`?([%a_][%w_]*)%s*[%*&%s`]")
    if t_base and t_base ~= "struct" and t_base ~= "class" and t_base ~= "const" and t_base ~= "int" and t_base ~= "char" and t_base ~= "void" then
      add(t_base)
    end

    local t3 = line:match("typedef%s+struct%s+([%w_]+)")
    if t3 then add(t3) end
    local t4 = line:match("###%s+type%-alias%s+`?([%w_]+)`?")
    if t4 then add(t4) end
  end
  return names
end

--- Resolves class/struct details across typeDefinition, definition, or current buffer symbols
function M.resolve_class_details(bufnr, client, params, cur_word, hover_lines, callback)
  local hover_types = M.extract_types_from_hover(hover_lines)
  local candidate_names = { cur_word }
  for _, ht in ipairs(hover_types) do
    table.insert(candidate_names, ht)
  end

  local function safe_load_buffer(target_uri)
    local target_path = vim.uri_to_fname(target_uri)
    local target_buf = vim.fn.bufadd(target_path)
    if not vim.api.nvim_buf_is_loaded(target_buf) then
      vim.bo[target_buf].swapfile = false
      local save_sm = vim.opt.shortmess:get()
      vim.opt.shortmess:append("A")
      pcall(vim.fn.bufload, target_buf)
      vim.opt.shortmess = save_sm
    end
    return target_buf
  end

  local function query_symbols_for_loc(loc, on_found, on_miss)
    if not loc or not loc.uri then
      on_miss()
      return
    end

    local target_buf = safe_load_buffer(loc.uri)
    local target_params = { textDocument = { uri = loc.uri } }
    client:request("textDocument/documentSymbol", target_params, function(ds_err, ds_res)
      if ds_err or not ds_res or #ds_res == 0 then
        on_miss()
        return
      end

      local target_line = loc.range and loc.range.start and loc.range.start.line
      local sym = M.find_class_symbol(ds_res, target_line, candidate_names)
      if sym and sym.children and #sym.children > 0 then
        local lines = M.format_class_details(target_buf, sym)
        on_found(lines)
      else
        on_miss()
      end
    end)
  end

  -- Strategy 1: Check textDocument/typeDefinition (ideal for typedefs, type aliases, variables)
  local supports_typedef = client.supports_method and client:supports_method("textDocument/typeDefinition")
  if supports_typedef then
    client:request("textDocument/typeDefinition", params, function(t_err, t_res)
      local loc = t_res and (t_res[1] or t_res)
      if loc and loc.targetUri then
        loc = { uri = loc.targetUri, range = loc.targetRange }
      end

      if loc and loc.uri then
        query_symbols_for_loc(loc, function(lines)
          callback(lines)
        end, function()
          -- Fallback from typeDefinition to definition
          M._resolve_definition_or_buffer(bufnr, client, params, candidate_names, callback)
        end)
      else
        M._resolve_definition_or_buffer(bufnr, client, params, candidate_names, callback)
      end
    end)
  else
    M._resolve_definition_or_buffer(bufnr, client, params, candidate_names, callback)
  end
end

--- Fallback resolver: checks textDocument/definition and then buffer documentSymbol
function M._resolve_definition_or_buffer(bufnr, client, params, candidate_names, callback)
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  local cur_line = cur_pos[1] - 1

  local supports_def = client.supports_method and client:supports_method("textDocument/definition")
  local function fallback_current_buffer()
    local cur_params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
    client:request("textDocument/documentSymbol", cur_params, function(ds_err, ds_res)
      if not ds_err and ds_res and #ds_res > 0 then
        local sym = M.find_class_symbol(ds_res, cur_line, candidate_names)
        if sym and sym.children and #sym.children > 0 then
          local lines = M.format_class_details(bufnr, sym)
          callback(lines)
          return
        end
      end
      callback(nil)
    end)
  end

  if supports_def then
    client:request("textDocument/definition", params, function(d_err, d_res)
      local loc = d_res and (d_res[1] or d_res)
      if loc and loc.targetUri then
        loc = { uri = loc.targetUri, range = loc.targetRange }
      end

      if loc and loc.uri then
        local target_path = vim.uri_to_fname(loc.uri)
        local target_buf = vim.fn.bufadd(target_path)
        if not vim.api.nvim_buf_is_loaded(target_buf) then
          vim.bo[target_buf].swapfile = false
          local save_sm = vim.opt.shortmess:get()
          vim.opt.shortmess:append("A")
          pcall(vim.fn.bufload, target_buf)
          vim.opt.shortmess = save_sm
        end

        local target_params = { textDocument = { uri = loc.uri } }
        client:request("textDocument/documentSymbol", target_params, function(ds_err, ds_res)
          if not ds_err and ds_res and #ds_res > 0 then
            local target_line = loc.range and loc.range.start and loc.range.start.line
            local sym = M.find_class_symbol(ds_res, target_line, candidate_names)
            if sym and sym.children and #sym.children > 0 then
              local lines = M.format_class_details(target_buf, sym)
              callback(lines)
              return
            end
          end
          fallback_current_buffer()
        end)
      else
        fallback_current_buffer()
      end
    end)
  else
    fallback_current_buffer()
  end
end

--- Inspects the class/struct under cursor and displays its components and methods
function M.inspect_class(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    vim.notify("No LSP client attached", vim.log.levels.INFO)
    return
  end

  local client = clients[1]
  local cur_word = vim.fn.expand("<cword>")
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)

  M.resolve_class_details(bufnr, client, params, cur_word, {}, function(lines)
    if lines and #lines > 0 then
      local util = require("vim.lsp.util")
      util.open_floating_preview(lines, "markdown", {
        border = "rounded",
        focus_id = "class_inspector",
      })
    else
      vim.notify("No class or struct details found for: " .. cur_word, vim.log.levels.INFO)
    end
  end)
end

--- Shows the floating popup with class breakdown
function M.show_class_popup(bufnr, class_sym)
  local lines = M.format_class_details(bufnr, class_sym)
  local util = require("vim.lsp.util")
  local k = class_sym.kind == 5 and "Class" or (class_sym.kind == 11 and "Interface" or "Struct")
  util.open_floating_preview(lines, "markdown", {
    border = "rounded",
    focus_id = "class_inspector",
    title = string.format(" %s %s ", k, class_sym.name),
  })
end

return M
