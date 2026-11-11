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

opt.splitright = true
opt.laststatus = 2
opt.number = true
opt.relativenumber = true
opt.smartindent = true
opt.tabstop = 8
opt.shiftwidth = 8
opt.expandtab = false

-- Ultra-low-latency input, key-chord, and redraw tuning (matching raw Linux TTY responsiveness)
opt.timeoutlen = 250
opt.ttimeoutlen = 5
opt.updatetime = 150
opt.synmaxcol = 300
opt.redrawtime = 1500

-- Non-blocking asynchronous Wayland/X11 clipboard provider for unnamedplus:
-- Eliminates the 22.7ms synchronous wl-copy freeze on every 'x', 'dd', 'dw', 'cw', and 'yy'!
if not is_win and (vim.env.WAYLAND_DISPLAY or vim.env.DISPLAY) then
    local has_wl = vim.env.WAYLAND_DISPLAY and vim.fn.executable("wl-copy") == 1 and vim.fn.executable("wl-paste") == 1
    local has_xclip = not has_wl and vim.env.DISPLAY and vim.fn.executable("xclip") == 1
    if has_wl or has_xclip then
        local cache_lines = { [""] = {} }
        local cache_type = { [""] = "v" }

        local function async_copy(lines, regtype)
            cache_lines[""] = lines
            cache_type[""] = regtype
            local text = table.concat(lines, "\n")
            if regtype == "V" or regtype == "\22" then
                text = text .. "\n"
            end
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

vim.api.nvim_create_autocmd({"WinEnter", "BufWinEnter", "TermOpen"}, {
    pattern = "term://*",
    callback = function() vim.cmd("startinsert") end,
})

vim.api.nvim_create_autocmd("TermOpen", {
    callback = function()
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
    end,
})

vim.api.nvim_create_autocmd("TermClose", {
    callback = function()
        vim.cmd("bdelete!")
    end,
})

vim.filetype.add({
  extension = {
    prisma = "prisma",
  },
})

