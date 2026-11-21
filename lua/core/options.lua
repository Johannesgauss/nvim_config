local opt = vim.opt
local uv = vim.uv or vim.loop

-- Automatically ensure user bin directories are in PATH across all environments (rg, fd, etc.)
local home = vim.env.HOME or vim.env.USERPROFILE or vim.fn.expand("~")
local is_win = uv and uv.os_uname().sysname:find("Windows") ~= nil or package.config:sub(1, 1) == "\\"
local path_sep = is_win and ";" or ":"
local current_path = vim.env.PATH or ""
local standard_bin_paths = {
    home .. "/.local/bin",
    home .. "/.cargo/bin",
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/opt/local/bin",
}
for _, dir in ipairs(standard_bin_paths) do
    local st = uv and uv.fs_stat(dir)
    if st and st.type == "directory" and not string.find(current_path, dir, 1, true) then
        current_path = dir .. path_sep .. current_path
    end
end
vim.env.PATH = current_path

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local function load_options_conf()
    local cfg = {
        tabstop = 8,
        shiftwidth = 8,
        expandtab = false,
        smartindent = true,
        undofile = true,
        ignorecase = true,
        smartcase = true,
        term_auto_insert = true,
        term_auto_close = true,
        timeoutlen = 250,
        ttimeoutlen = 5,
        updatetime = 150,
        synmaxcol = 300,
        redrawtime = 1500,
        lsp_log_level = "error",
    }

    local conf_path = vim.fs.joinpath(vim.fn.stdpath("config"), "options.conf")
    if vim.fn.filereadable(conf_path) ~= 1 then
        return cfg
    end

    for _, raw_line in ipairs(vim.fn.readfile(conf_path)) do
        local line = vim.trim(raw_line)
        if line ~= "" and not line:match("^#") and not line:match("^//") then
            local key, val = line:match("^([^=]+)%s*=%s*(.+)$")
            if key and val then
                key = vim.trim(key):lower()
                if val:find("#") then
                    val = vim.split(val, "#")[1]
                end
                val = vim.trim(val)
                local lower = val:lower()
                if cfg[key] ~= nil then
                    if type(cfg[key]) == "boolean" then
                        if lower == "true" or lower == "1" or lower == "yes" or lower == "on" then
                            cfg[key] = true
                        elseif lower == "false" or lower == "0" or lower == "no" or lower == "off" then
                            cfg[key] = false
                        end
                    elseif type(cfg[key]) == "number" then
                        local num = tonumber(val)
                        if num then
                            cfg[key] = num
                        end
                    else
                        cfg[key] = lower
                    end
                end
            end
        end
    end

    return cfg
end

local user_opts = load_options_conf()

opt.splitright = true
opt.laststatus = 2
opt.number = true
opt.relativenumber = true
opt.smartindent = user_opts.smartindent
opt.tabstop = user_opts.tabstop
opt.shiftwidth = user_opts.shiftwidth
opt.expandtab = user_opts.expandtab
opt.undofile = user_opts.undofile
opt.ignorecase = user_opts.ignorecase
opt.smartcase = user_opts.smartcase

-- Prevent unbounded ~/.local/state/nvim/lsp.log growth
if vim.lsp and vim.lsp.log and type(vim.lsp.log.set_level) == "function" then
    pcall(vim.lsp.log.set_level, user_opts.lsp_log_level)
elseif vim.lsp and type(vim.lsp.set_log_level) == "function" then
    pcall(vim.lsp.set_log_level, user_opts.lsp_log_level)
end

-- Ultra-low-latency input, key-chord, and redraw tuning (matching raw Linux TTY responsiveness)
opt.timeoutlen = user_opts.timeoutlen
opt.ttimeoutlen = user_opts.ttimeoutlen
opt.updatetime = user_opts.updatetime
opt.synmaxcol = user_opts.synmaxcol
opt.redrawtime = user_opts.redrawtime

-- Non-blocking asynchronous Wayland/X11 clipboard provider for unnamedplus:
-- Eliminates the 22.7ms synchronous wl-copy freeze on every 'x', 'dd', 'dw', 'cw', and 'yy'!
if not is_win and (vim.env.WAYLAND_DISPLAY or vim.env.DISPLAY) then
    local has_wl = vim.env.WAYLAND_DISPLAY and vim.fn.executable("wl-copy") == 1 and vim.fn.executable("wl-paste") == 1
    local has_xclip = not has_wl and vim.env.DISPLAY and vim.fn.executable("xclip") == 1
    if has_wl or has_xclip then
        local cache_lines = { [""] = {} }
        local cache_type = { [""] = "v" }
        local cache_text = nil

        local function async_copy(lines, regtype)
            cache_lines[""] = lines
            cache_type[""] = regtype
            local text = table.concat(lines, "\n")
            if regtype == "V" or regtype == "\22" then
                text = text .. "\n"
            end
            cache_text = text
            local cmd = has_wl and { "wl-copy", "--" } or { "xclip", "-quiet", "-i", "-selection", "clipboard" }
            pcall(vim.system, cmd, { stdin = text, detach = true })
        end

        local function sync_paste()
            local cmd = has_wl and { "wl-paste", "--no-newline" } or { "xclip", "-o", "-selection", "clipboard" }
            local ok, proc = pcall(vim.system, cmd, { text = true })
            if ok and proc then
                local res = proc:wait(300)
                if res and res.code == 0 and res.stdout then
                    local out = res.stdout:gsub("\r\n", "\n")
                    if cache_text ~= nil and out == cache_text then
                        return cache_lines[""] or {}, cache_type[""] or "v"
                    end
                    if out:sub(-1) == "\n" then
                        return vim.split(out:sub(1, -2), "\n", { plain = true }), "V"
                    end
                    return vim.split(out, "\n", { plain = true }), "v"
                end
            end
            return cache_lines[""] or {}, cache_type[""] or "v"
        end

        vim.g.clipboard = {
            name = "AsyncSystemClipboard",
            copy = {
                ["+"] = async_copy,
                ["*"] = async_copy,
            },
            paste = {
                ["+"] = sync_paste,
                ["*"] = sync_paste,
            },
            cache_enabled = 0,
        }
    end
end

opt.clipboard = "unnamedplus"

if user_opts.term_auto_insert then
    vim.api.nvim_create_autocmd({"WinEnter", "BufWinEnter", "TermOpen"}, {
        pattern = "term://*",
        callback = function() vim.cmd("startinsert") end,
    })
end

vim.api.nvim_create_autocmd("TermOpen", {
    callback = function()
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
    end,
})

if user_opts.term_auto_close then
    vim.api.nvim_create_autocmd("TermClose", {
        callback = function()
            vim.cmd("bdelete!")
        end,
    })
end

vim.filetype.add({
  extension = {
    prisma = "prisma",
  },
})

