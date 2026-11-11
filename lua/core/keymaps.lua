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

    -- Markdown & LaTeX Viewing
    ["markdown:toggle_view"] = function()
        require("ui.markdown_view").toggle()
    end,
    ["markdown:toggle_render"] = function()
        local ok, rm = pcall(require, "render-markdown")
        if ok and rm.toggle then
            rm.toggle()
        else
            vim.cmd("RenderMarkdown toggle")
        end
    end,
    ["latex:popup"] = function()
        local ok, _ = pcall(vim.cmd, "NablaPopup")
        if not ok then
            pcall(function() require("nabla").popup({ border = "rounded" }) end)
        end
    end,
    ["latex:toggle_virt"] = function()
        local ok, _ = pcall(vim.cmd, "NablaToggle")
        if not ok then
            pcall(function() require("nabla").toggle_virt() end)
        end
    end,

    -- LSP Diagnostics & Documentation
    ["lsp:diagnostic_float"] = function()
        vim.diagnostic.open_float(nil, { focusable = true, border = "rounded", source = "always" })
    end,
    ["lsp:hover_doc"] = function()
        local bufnr = vim.api.nvim_get_current_buf()
        local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" })
        if #clients > 0 then
            vim.lsp.buf.hover()
        else
            local cword = vim.fn.expand("<cword>")
            if cword and cword ~= "" then
                local ok = pcall(vim.cmd.help, cword)
                if not ok then
                    vim.cmd("normal! K")
                end
            end
        end
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
    ["ai:antigravity_diffview"] = function()
        local ok, agy = pcall(require, "ai.antigravity")
        if ok and agy.toggle_diffview then agy.toggle_diffview() end
    end,
    ["ai:claude_toggle"] = function()
        local ok, cc = pcall(require, "ai.claudecode")
        if ok and cc.toggle then cc.toggle() end
    end,
    ["ai:copilot_chat"] = function()
        local ok, cp = pcall(require, "ai.copilot")
        if ok and cp.toggle_chat then cp.toggle_chat() end
    end,
    ["ai:copilot_reset"] = function()
        local ok, cp = pcall(require, "ai.copilot")
        if ok and cp.reset_chat then cp.reset_chat() end
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

vim.api.nvim_create_user_command("ToggleMarkdownView", function()
    require("ui.markdown_view").toggle()
end, { desc = "Toggle Markdown Reader Mode (Distraction-Free)" })

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
local function load_shortcuts_conf()
    local conf_path = vim.fs.joinpath(vim.fn.stdpath("config"), "shortcuts.conf")
    if vim.fn.filereadable(conf_path) ~= 1 then
        return false
    end

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

                    local mode_str = inline_mode or current_mode
                    local modes = {}
                    for m in mode_str:gmatch("%a") do
                        table.insert(modes, m)
                    end
                    if #modes == 0 then modes = { "n" } end

                    local handler
                    if actions[action] then
                        handler = actions[action]
                    else
                        handler = action
                    end

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
    return true
end

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
