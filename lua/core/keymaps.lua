local keymap = vim.keymap

-- ============================================================================
-- Terminal Toggle Manager
-- ============================================================================
local term_buf = nil
local term_win = nil

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
    return cur_win
end

local function toggle_terminal()
    if term_win and vim.api.nvim_win_is_valid(term_win) then
        vim.api.nvim_win_close(term_win, true)
        term_win = nil
    else
        local main_win = get_main_win()
        vim.api.nvim_set_current_win(main_win)

        local height = math.floor(vim.o.lines * 0.20)
        vim.cmd("belowright " .. height .. "split")
        term_win = vim.api.nvim_get_current_win()
        vim.wo[term_win].winfixheight = true
        if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
            vim.api.nvim_win_set_buf(term_win, term_buf)
        else
            vim.cmd("terminal")
            term_buf = vim.api.nvim_get_current_buf()
        end
        vim.cmd("startinsert")
    end
end

-- ============================================================================
-- Lazygit Integration
-- ============================================================================
local function open_lazygit()
    vim.cmd("tabnew")
    vim.cmd("terminal lazygit")
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false

    vim.api.nvim_create_autocmd("TermClose", {
        buffer = vim.api.nvim_get_current_buf(),
        once = true,
        callback = function() vim.cmd("tabclose") end,
    })
    vim.cmd("startinsert")
end

-- ============================================================================
-- Named Action Dispatcher
-- ============================================================================
local actions = {
    -- Terminal & Lazygit
    ["terminal:toggle"] = toggle_terminal,
    ["lazygit:open"] = open_lazygit,

    -- LSP Diagnostics, Navigation & Code Actions (lazy-wrapped to avoid loading vim.lsp on startup)
    ["lsp:definition"] = function() vim.lsp.buf.definition() end,
    ["lsp:declaration"] = function() vim.lsp.buf.declaration() end,
    ["lsp:implementation"] = function() vim.lsp.buf.implementation() end,
    ["lsp:references"] = function() vim.lsp.buf.references() end,
    ["lsp:rename"] = function() vim.lsp.buf.rename() end,
    ["lsp:code_action"] = function() vim.lsp.buf.code_action() end,
    ["lsp:diagnostic_prev"] = function() vim.diagnostic.goto_prev() end,
    ["lsp:diagnostic_next"] = function() vim.diagnostic.goto_next() end,
    ["lsp:diagnostic_loclist"] = function() vim.diagnostic.setloclist() end,
    ["lsp:document_symbol"] = function() vim.lsp.buf.document_symbol() end,
    ["lsp:class_inspector"] = function()
        local ok, ci = pcall(require, "core.class_inspector")
        if ok and ci.inspect_class then ci.inspect_class(0) end
    end,
    ["lsp:signature_help"] = function()
        vim.lsp.buf.signature_help({
            close_events = { "InsertLeave", "BufLeave" },
            anchor_bias = "above",
        })
    end,
    ["lsp:toggle_inlay_hints"] = function()
        local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
        vim.lsp.inlay_hint.enable(not enabled, { bufnr = 0 })
    end,
    ["lsp:diagnostic_float"] = function()
        vim.diagnostic.open_float(nil, { focusable = true, border = "rounded", source = "always" })
    end,
    ["lsp:hover_doc"] = function()
        local bufnr = vim.api.nvim_get_current_buf()
        local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" })
        if #clients == 0 then
            local cword = vim.fn.expand("<cword>")
            if cword and cword ~= "" then
                local ok = pcall(vim.cmd.help, cword)
                if not ok then
                    vim.cmd("normal! K")
                end
            end
            return
        end

        local cur_word = vim.fn.expand("<cword>")
        local client = clients[1]
        local h_params = vim.lsp.util.make_position_params(0, client.offset_encoding)
        local ok_ci, class_inspector = pcall(require, "core.class_inspector")

        client:request("textDocument/hover", h_params, function(h_err, h_result)
            local lines = {}
            if not h_err and h_result and h_result.contents then
                lines = vim.lsp.util.convert_input_to_markdown_lines(h_result.contents)
            end

            if ok_ci and class_inspector and class_inspector.resolve_class_details then
                class_inspector.resolve_class_details(bufnr, client, h_params, cur_word, lines, function(class_lines)
                    if class_lines and #class_lines > 0 then
                        if #lines > 0 then
                            table.insert(lines, "")
                            table.insert(lines, "---")
                        end
                        for _, cl in ipairs(class_lines) do
                            table.insert(lines, cl)
                        end
                    end

                    if #lines > 0 then
                        vim.lsp.util.open_floating_preview(lines, "markdown", {
                            border = "rounded",
                            focus_id = "textDocument/hover",
                        })
                    else
                        vim.notify("No information available", vim.log.levels.INFO)
                    end
                end)
            else
                if #lines > 0 then
                    vim.lsp.util.open_floating_preview(lines, "markdown", {
                        border = "rounded",
                        focus_id = "textDocument/hover",
                    })
                else
                    vim.notify("No information available", vim.log.levels.INFO)
                end
            end
        end)
    end,

    -- Plain CLI GDB (Auto-Compile & Debug Current File)
    ["gdb:debug"] = function()
        local bufnr = vim.api.nvim_get_current_buf()
        local filepath = vim.api.nvim_buf_get_name(bufnr)
        if filepath == "" then
            vim.notify("Buffer has no file name", vim.log.levels.ERROR)
            return
        end

        vim.cmd("silent! update")

        local ft = vim.bo[bufnr].filetype
        local file_dir = vim.fn.fnamemodify(filepath, ":p:h")
        local stem = vim.fn.fnamemodify(filepath, ":t:r")
        local is_win = vim.fn.has("win32") == 1
        local tmp_dir = is_win and vim.fn.fnamemodify(vim.fn.tempname(), ":h") or "/tmp"
        local out_bin = vim.fs.joinpath(tmp_dir, "gdb_" .. stem .. (is_win and ".exe" or ""))
        local cmd = nil

        if ft == "cpp" then
            local cxx = vim.fn.executable("g++") == 1 and "g++" or "clang++"
            cmd = { cxx, "-g", "-O0", "-std=c++20", "-DLOCAL", "-Wall", filepath, "-o", out_bin }
        elseif ft == "c" then
            local cc = vim.fn.executable("gcc") == 1 and "gcc" or "clang"
            cmd = { cc, "-g", "-O0", "-DLOCAL", "-Wall", filepath, "-o", out_bin, "-lm" }
        elseif ft == "rust" then
            local cargo_dir = vim.fs.root(filepath, { "Cargo.toml" })
            if cargo_dir then
                local build = vim.system({ "cargo", "build" }, { cwd = cargo_dir, text = true }):wait()
                if build.code ~= 0 then
                    vim.notify("Cargo build failed:\n" .. (build.stderr or build.stdout or ""), vim.log.levels.ERROR)
                    return
                end
                local pkg_name = vim.fn.fnamemodify(cargo_dir, ":t")
                local cargo_bin = vim.fs.joinpath(cargo_dir, "target", "debug", pkg_name)
                if vim.fn.executable(cargo_bin) == 1 then
                    out_bin = cargo_bin
                    file_dir = cargo_dir
                else
                    cmd = { "rustc", "-g", filepath, "-o", out_bin }
                end
            else
                cmd = { "rustc", "-g", filepath, "-o", out_bin }
            end
        else
            vim.notify("Unsupported filetype for GDB auto-compile: " .. tostring(ft), vim.log.levels.WARN)
            return
        end

        if cmd then
            local res = vim.system(cmd, { cwd = file_dir, text = true }):wait()
            if res.code ~= 0 then
                vim.notify("Compilation failed:\n" .. (res.stderr or res.stdout or ""), vim.log.levels.ERROR)
                return
            end
        end

        local main_win = get_main_win()
        vim.api.nvim_set_current_win(main_win)
        local height = math.floor(vim.o.lines * 0.35)
        vim.cmd("belowright " .. height .. "split | enew")
        local gdb_win = vim.api.nvim_get_current_win()
        vim.wo[gdb_win].winfixheight = true
        if vim.fn.executable("gdb") == 1 then
            vim.fn.termopen({ "gdb", "-q", "-ex", "set print pretty on", out_bin }, { cwd = file_dir })
        elseif vim.fn.executable("lldb") == 1 then
            vim.fn.termopen({ "lldb", out_bin }, { cwd = file_dir })
        else
            vim.notify("Neither gdb nor lldb found in PATH", vim.log.levels.ERROR)
            return
        end
        vim.cmd("startinsert")
    end,

    -- AI Integrations
    ["ai:antigravity_toggle"] = function()
        local ok, agy = pcall(require, "ai.antigravity")
        if ok and agy.toggle then agy.toggle() end
    end,
    ["ai:antigravity_auto"] = function()
        local ok, agy = pcall(require, "ai.antigravity")
        if ok and agy.toggle_auto then agy.toggle_auto() end
    end,
    ["ai:antigravity_diffview"] = function()
        local ok, agy = pcall(require, "ai.antigravity")
        if ok and agy.toggle_diffview then agy.toggle_diffview() end
    end,
    ["ai:antigravity_resize_small"] = function()
        local ok, agy = pcall(require, "ai.antigravity")
        if ok and agy.resize then agy.resize(0.25) end
    end,
    ["ai:antigravity_resize_med"] = function()
        local ok, agy = pcall(require, "ai.antigravity")
        if ok and agy.resize then agy.resize(0.42) end
    end,
    ["ai:antigravity_resize_large"] = function()
        local ok, agy = pcall(require, "ai.antigravity")
        if ok and agy.resize then agy.resize(0.65) end
    end,
    ["ai:claude_toggle"] = function()
        local ok, cc = pcall(require, "ai.claudecode")
        if ok and cc.toggle then cc.toggle() end
    end,
    ["ai:claude_resize_small"] = function()
        local ok, cc = pcall(require, "ai.claudecode")
        if ok and cc.resize then cc.resize(0.25) end
    end,
    ["ai:claude_resize_med"] = function()
        local ok, cc = pcall(require, "ai.claudecode")
        if ok and cc.resize then cc.resize(0.65) end
    end,
    ["ai:claude_resize_full"] = function()
        local ok, cc = pcall(require, "ai.claudecode")
        if ok and cc.resize then cc.resize(1.00) end
    end,
    ["ai:copilot_chat"] = function()
        local ok, cp = pcall(require, "ai.copilot")
        if ok and cp.toggle_chat then cp.toggle_chat() end
    end,
    ["ai:copilot_reset"] = function()
        local ok, cp = pcall(require, "ai.copilot")
        if ok and cp.reset_chat then cp.reset_chat() end
    end,
    ["ai:copilot_accept"] = function()
        local ok, cp = pcall(require, "ai.copilot")
        if ok and cp.accept and cp.accept() then
            return
        end
        local key = vim.api.nvim_replace_termcodes("<C-e>", true, true, true)
        vim.api.nvim_feedkeys(key, "n", false)
    end,
    ["ai:copilot_next"] = function()
        local ok, cp = pcall(require, "ai.copilot")
        if ok and cp.next then cp.next() end
    end,
    ["ai:ollama_complete"] = function()
        local ok, ol = pcall(require, "ai.ollama")
        if ok and ol.complete then ol.complete() end
    end,
    ["ai:ollama_model_swap"] = function()
        local ok, ol = pcall(require, "ai.ollama")
        if ok and ol.swap_model then ol.swap_model() end
    end,
}

-- ============================================================================
-- Global User Commands
-- ============================================================================
vim.api.nvim_create_user_command("ToggleTTY", function()
    require("ui.vim_look").toggle_tty()
end, { desc = "Toggle classic TTY mode with ASCII borders" })

vim.api.nvim_create_user_command("ToggleVimLook", function()
    require("ui.vim_look").toggle()
end, { desc = "Toggle between classic and modern Vim look" })

vim.api.nvim_create_user_command("Cowabuga", function(opts)
    require("core.cowabuga").command(opts.args)
end, {
    nargs = "*",
    complete = function(arg_lead, cmd_line, cursor_pos)
        return require("core.cowabuga").complete(arg_lead, cmd_line, cursor_pos)
    end,
    desc = "Set or toggle unity build include file for clangd LSP (:Cowabuga [file|--status|--clear])",
})

vim.api.nvim_create_user_command("Cowabunga", function(opts)
    require("core.cowabuga").command(opts.args)
end, {
    nargs = "*",
    complete = function(arg_lead, cmd_line, cursor_pos)
        return require("core.cowabuga").complete(arg_lead, cmd_line, cursor_pos)
    end,
    desc = "Set or toggle unity build include file for clangd LSP (alias)",
})

-- ============================================================================
-- Linux-Style Configuration Loader (shortcuts.conf)
-- ============================================================================
local optional_prefixes = {
    markdown = true,
    latex = true,
    docx = true,
}

local function load_shortcuts_conf()
    local conf_path = vim.fs.joinpath(vim.fn.stdpath("config"), "shortcuts.conf")
    if vim.fn.filereadable(conf_path) ~= 1 then
        return false
    end

    local features = require("core.features")
    features.load()
    local mod_actions = require("modules").actions()

    local lines = vim.fn.readfile(conf_path)
    local current_mode = "n"

    for _, raw_line in ipairs(lines) do
        local line = vim.trim(raw_line)
        -- Skip empty lines and full comment lines (# or //)
        if line ~= "" and not line:match("^#") and not line:match("^//") then
            -- Section header: [i], [t], [v], [n], or [n,v]
            local sec = line:match("^%[([%a,]+)%]$")
            if sec then
                current_mode = sec
            else
                -- Format: [mode] key = action # desc   OR   key = action # desc
                local inline_mode, key, action = line:match("^%[([%a,]+)%]%s*([^=]+)%s*=%s*(.+)$")
                if not key then
                    key, action = line:match("^([^=]+)%s*=%s*(.+)$")
                end

                if key and action then
                    key = vim.trim(key)
                    action = vim.trim(action)
                    local desc = ""

                    -- Parse optional inline comment: action # description
                    if action:find("#") then
                        local parts = vim.split(action, "#")
                        action = vim.trim(parts[1])
                        desc = vim.trim(parts[2] or "")
                    end

                    -- Check if action belongs to an optional feature that is disabled
                    local prefix = action:match("^([%a_]+):")
                    local skip = false
                    if prefix and optional_prefixes[prefix] and not features.is_enabled(prefix) then
                        skip = true
                    end

                    if not skip then
                        local mode_str = inline_mode or current_mode
                        local modes = {}
                        for m in mode_str:gmatch("%a") do
                            table.insert(modes, m)
                        end
                        if #modes == 0 then modes = { "n" } end

                        local handler = mod_actions[action] or actions[action] or action

                        for _, m in ipairs(modes) do
                            keymap.set(m, key, handler, {
                                desc = desc ~= "" and desc or nil,
                                silent = true,
                            })
                        end
                    end
                end
            end
        end
    end
    return true
end

vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = { "shortcuts.conf", "features.conf" },
    callback = function(ev)
        load_shortcuts_conf()
        vim.notify(vim.fn.fnamemodify(ev.file, ":t") .. " reloaded", vim.log.levels.INFO)
    end,
})

-- Try loading Linux-style shortcuts.conf first; fallback to lua/config/shortcuts.lua if absent
if not load_shortcuts_conf() then
    local ok_shortcuts, shortcuts = pcall(require, "config.shortcuts")
    if ok_shortcuts and type(shortcuts) == "table" then
        for _, item in ipairs(shortcuts) do
            local key = item[1] or item.key
            local target = item[2] or item.action
            local mode = item.mode or "n"
            local desc = item.desc or ""

            if key and target then
                local handler = (type(target) == "string" and actions[target]) or target
                keymap.set(mode, key, handler, {
                    desc = desc,
                    silent = true,
                })
            end
        end
    end
end
