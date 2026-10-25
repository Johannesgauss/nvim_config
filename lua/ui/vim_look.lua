local M = {}

local state_dir = vim.fn.stdpath("state")
local state_file = state_dir .. "/vim_look_enabled"
local tty_state_file = state_dir .. "/tty_mode_enabled"

local ASCII_BORDER = { "+", "-", "+", "|", "+", "-", "+", "|" }

local is_vim_look = false
local is_tty_mode = false
local has_captured = false
local saved = {
    colors_name = "catppuccin-mocha",
    termguicolors = true,
    statusline = "%!v:lua.Render_Statusline()",
    relativenumber = true,
    signcolumn = "auto",
    cursorline = false,
    showmode = false,
    ruler = false,
    showcmd = true,
    fillchars = nil,
    listchars = nil,
    clipboard = "unnamedplus",
}

local function read_persisted_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    if not content then return nil end
    return vim.trim(content) == "true"
end

local function write_persisted_file(path, enabled)
    if vim.fn.isdirectory(state_dir) == 0 then
        vim.fn.mkdir(state_dir, "p")
    end
    local f = io.open(path, "w")
    if f then
        f:write(enabled and "true" or "false")
        f:close()
    end
end

local function read_persisted_state()
    return read_persisted_file(state_file) == true
end

local function write_persisted_state(enabled)
    write_persisted_file(state_file, enabled)
end

local function is_tty_environment()
    local term = vim.env.TERM or ""

    -- 1. Linux virtual console ($TERM is linux, linux-m, fbcon, console)
    if term == "linux" or term:match("^linux%-") or term == "fbcon" or term == "console" then
        return true
    end

    -- 2. Serial and hardware terminals across systems (vt100, vt102, vt220, cons25, dumb)
    if term:match("^vt%d+") or term:match("^cons%d+") or term == "dumb" then
        return true
    end

    -- 3. Terminal device check via tty(1)
    -- Linux virtual consoles return /dev/tty1 .. /dev/tty63
    -- Serial consoles return /dev/ttyS*, /dev/ttyUSB*, /dev/ttyAMA*
    -- BSD virtual consoles return /dev/ttyv*
    if vim.fn.executable("tty") == 1 then
        local ok, tty_out = pcall(function()
            return vim.trim(vim.fn.system("tty") or "")
        end)
        if ok and tty_out and tty_out ~= "" then
            if tty_out:match("^/dev/tty%d+$")
                or tty_out:match("^/dev/console$")
                or tty_out:match("^/dev/ttyv%d")
                or tty_out:match("^/dev/ttyS")
                or tty_out:match("^/dev/ttyUSB")
                or tty_out:match("^/dev/ttyAMA") then
                return true
            end
        end
    end

    -- 4. Environment fallback: No GUI display server AND no colorterm AND not a 256color terminal emulator
    local no_display = (not vim.env.DISPLAY or vim.env.DISPLAY == "")
        and (not vim.env.WAYLAND_DISPLAY or vim.env.WAYLAND_DISPLAY == "")
    local no_colorterm = (not vim.env.COLORTERM or vim.env.COLORTERM == "")
    if no_display and no_colorterm and not term:match("256color") and not term:match("kitty") and not term:match("alacritty") and not term:match("xterm") then
        return true
    end

    return false
end

local function should_enable_tty_on_startup()
    local in_tty = is_tty_environment()
    local persisted = read_persisted_file(tty_state_file)
    if persisted ~= nil then
        return persisted
    end
    -- Automatically enable if running in any TTY environment across any OS/distro
    return in_tty
end

local function write_tty_persisted_state(enabled)
    write_persisted_file(tty_state_file, enabled)
end

-- Wrap floating window utilities so TTY mode always renders pure-ASCII borders
if vim.lsp and vim.lsp.util and type(vim.lsp.util.open_floating_preview) == "function" then
    local orig_open_floating_preview = vim.lsp.util.open_floating_preview
    vim.lsp.util.open_floating_preview = function(contents, syntax, opts)
        opts = opts or {}
        if vim.g.tty_mode then
            opts.border = ASCII_BORDER
        end
        return orig_open_floating_preview(contents, syntax, opts)
    end
end

if vim.diagnostic and type(vim.diagnostic.open_float) == "function" then
    local orig_diag_open_float = vim.diagnostic.open_float
    vim.diagnostic.open_float = function(bufnr, opts)
        if type(bufnr) == "table" and opts == nil then
            opts = bufnr
            bufnr = nil
        end
        opts = opts or {}
        if vim.g.tty_mode then
            opts.border = ASCII_BORDER
        end
        return orig_diag_open_float(bufnr, opts)
    end
end

local function apply_win_options(rnu, signcol, curline)
    vim.opt.number = true
    vim.opt.relativenumber = rnu
    vim.opt.signcolumn = signcol
    vim.opt.cursorline = curline

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype ~= "terminal" then
                vim.wo[win].number = true
                vim.wo[win].relativenumber = rnu
                vim.wo[win].signcolumn = signcol
                vim.wo[win].cursorline = curline
            end
        end
    end
end

local function capture_modern_state()
    if has_captured then return end
    saved.termguicolors = vim.o.termguicolors
    saved.colors_name = vim.g.colors_name or "catppuccin-mocha"
    saved.statusline = vim.o.statusline
    saved.relativenumber = vim.wo.relativenumber
    saved.signcolumn = vim.wo.signcolumn
    saved.cursorline = vim.wo.cursorline
    saved.showmode = vim.o.showmode
    saved.ruler = vim.o.ruler
    saved.showcmd = vim.o.showcmd
    saved.fillchars = vim.opt.fillchars:get()
    saved.listchars = vim.opt.listchars:get()
    saved.clipboard = vim.o.clipboard
    has_captured = true
end

local function apply_diagnostics(tty)
    local signs = tty and {
        Error = "E",
        Warn = "W",
        Hint = "H",
        Info = "I",
    } or {
        Error = "✘",
        Warn = "▲",
        Hint = "⚑",
        Info = "»",
    }

    for type_name, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type_name
        pcall(vim.fn.sign_define, hl, { text = icon, texthl = hl, numhl = hl })
    end

    pcall(vim.diagnostic.config, {
        virtual_text = { prefix = tty and "*" or "●" },
        signs = {
            text = {
                [vim.diagnostic.severity.ERROR] = signs.Error,
                [vim.diagnostic.severity.WARN] = signs.Warn,
                [vim.diagnostic.severity.HINT] = signs.Hint,
                [vim.diagnostic.severity.INFO] = signs.Info,
            },
        },
        underline = true,
        severity_sort = true,
        float = {
            border = tty and ASCII_BORDER or "rounded",
            source = "always",
        },
    })
end

local function apply_tty_plugins(tty)
    -- 1. NvimTree: switch between NERDTree-style ASCII glyphs and Nerd Font icons
    if type(_G.Setup_NvimTree) == "function" then
        pcall(_G.Setup_NvimTree, tty)
    end

    -- 2. nvim-cmp: switch completion/documentation popup borders to pure ASCII
    if package.loaded["cmp"] then
        local ok_cmp, cmp = pcall(require, "cmp")
        if ok_cmp and cmp.setup then
            local border = tty and ASCII_BORDER or "rounded"
            pcall(cmp.setup, {
                window = {
                    completion = cmp.config.window.bordered({ border = border }),
                    documentation = cmp.config.window.bordered({ border = border }),
                },
            })
        end
    end

    -- 3. Telescope: switch borders and prompts to pure ASCII without devicons
    if package.loaded["telescope"] then
        local ok_tel, telescope = pcall(require, "telescope")
        if ok_tel and telescope.setup then
            if tty then
                pcall(telescope.setup, {
                    defaults = {
                        color_devicons = false,
                        disable_devicons = true,
                        prompt_prefix = "> ",
                        selection_caret = "* ",
                        borderchars = { "-", "|", "-", "|", "+", "+", "+", "+" },
                    },
                })
            else
                pcall(telescope.setup, {
                    defaults = {
                        color_devicons = true,
                        disable_devicons = false,
                        prompt_prefix = "> ",
                        selection_caret = "> ",
                        borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
                    },
                })
            end
        end
    end

    -- 4. render-markdown: switch table borders and icons between pure ASCII and Unicode
    if package.loaded["render-markdown"] then
        local ok_rm, rm = pcall(require, "render-markdown")
        if ok_rm and rm.setup then
            if tty then
                pcall(rm.setup, {
                    heading = { icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " } },
                    bullet = { icons = { "*", "-", "+", "*" } },
                    pipe_table = {
                        border = { "+", "+", "+", "+", "+", "+", "+", "+", "+", "|", "-" },
                    },
                })
            else
                pcall(rm.setup, {
                    heading = { icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " } },
                    bullet = { icons = { "●", "○", "◆", "◇" } },
                    pipe_table = {
                        border = { "┌", "┬", "┐", "├", "┼", "┤", "└", "┴", "┘", "│", "─" },
                    },
                })
            end
        end
    end
end

local function apply_tty_highlights()
    -- Ensure 16-color VGA console (tty3) readability for splits, floats, popups, and signs
    vim.api.nvim_set_hl(0, "SignColumn", { ctermbg = "NONE", bg = "NONE" })
    vim.api.nvim_set_hl(0, "VertSplit", { ctermfg = 7, ctermbg = "NONE", fg = "LightGrey", bg = "NONE" })
    vim.api.nvim_set_hl(0, "WinSeparator", { ctermfg = 7, ctermbg = "NONE", fg = "LightGrey", bg = "NONE" })
    vim.api.nvim_set_hl(0, "NormalFloat", { ctermfg = 7, ctermbg = 0, fg = "LightGrey", bg = "Black" })
    vim.api.nvim_set_hl(0, "FloatBorder", { ctermfg = 7, ctermbg = 0, fg = "LightGrey", bg = "Black" })
    vim.api.nvim_set_hl(0, "Pmenu", { ctermfg = 7, ctermbg = 0, fg = "LightGrey", bg = "Black" })
    vim.api.nvim_set_hl(0, "PmenuSel", { ctermfg = 0, ctermbg = 7, fg = "Black", bg = "LightGrey", bold = true })
end

local function enable_vim_look(notify)
    vim.o.termguicolors = false
    local ok_cs = pcall(vim.cmd.colorscheme, "vim")
    if not ok_cs then
        pcall(vim.cmd.colorscheme, "default")
    end
    vim.o.statusline = "%<%f %h%m%r%=%-14.(%l,%c%V%) %P"
    vim.o.showmode = true
    vim.o.ruler = true
    vim.o.showcmd = true
    vim.opt.fillchars = { eob = "~", vert = "|" }
    apply_win_options(true, saved.signcolumn or "auto", false)

    -- Ensure sign column blends seamlessly with background in 16-color mode
    vim.api.nvim_set_hl(0, "SignColumn", { ctermbg = "NONE", bg = "NONE" })

    -- Maintain full diagnostic error indicators
    apply_diagnostics(is_tty_mode)

    is_vim_look = true
    if notify then
        vim.notify("Classic Vim look enabled (remembered across restarts)", vim.log.levels.INFO)
    end
end

local function disable_vim_look(notify)
    vim.o.termguicolors = (saved.termguicolors ~= nil) and saved.termguicolors or true
    pcall(vim.cmd.colorscheme, saved.colors_name or "catppuccin-mocha")
    vim.o.statusline = (saved.statusline and saved.statusline ~= "") and saved.statusline or "%!v:lua.Render_Statusline()"
    vim.o.showmode = (saved.showmode ~= nil) and saved.showmode or false
    vim.o.ruler = (saved.ruler ~= nil) and saved.ruler or false
    vim.o.showcmd = (saved.showcmd ~= nil) and saved.showcmd or true

    if saved.fillchars then
        vim.opt.fillchars = saved.fillchars
    end

    apply_win_options(
        (saved.relativenumber ~= nil) and saved.relativenumber or true,
        saved.signcolumn or "auto",
        (saved.cursorline ~= nil) and saved.cursorline or false
    )

    apply_diagnostics(false)

    is_vim_look = false
    if notify then
        vim.notify("Modern look restored (remembered across restarts)", vim.log.levels.INFO)
    end
end

local function enable_tty_mode(notify)
    vim.g.tty_mode = true
    is_tty_mode = true

    -- Apply base classic Vim look (16-color palette, statusline, ruler, showmode)
    enable_vim_look(false)

    -- Pure-ASCII fillchars and listchars for Linux virtual consoles (tty3)
    vim.opt.fillchars = { eob = "~", vert = "|", fold = "-", diff = "-", msgsep = "-" }
    vim.opt.listchars = { tab = ">-", trail = "-", extends = ">", precedes = "<", nbsp = "+" }

    -- Avoid clipboard hangs in headless TTYs when no X11/Wayland server is running
    if (not vim.env.DISPLAY or vim.env.DISPLAY == "") and (not vim.env.WAYLAND_DISPLAY or vim.env.WAYLAND_DISPLAY == "") then
        vim.opt.clipboard = ""
    end

    apply_tty_highlights()
    apply_diagnostics(true)
    apply_tty_plugins(true)

    if notify then
        vim.notify("TTY + Classic Vim mode enabled for tty3 (remembered across restarts)", vim.log.levels.INFO)
    end
end

local function disable_tty_mode(notify)
    vim.g.tty_mode = false
    is_tty_mode = false

    if saved.listchars then
        vim.opt.listchars = saved.listchars
    end
    if saved.clipboard ~= nil then
        vim.opt.clipboard = saved.clipboard
    end

    apply_tty_plugins(false)

    if read_persisted_state() then
        enable_vim_look(false)
    else
        disable_vim_look(false)
    end

    if notify then
        vim.notify("TTY mode disabled; modern UI restored (remembered across restarts)", vim.log.levels.INFO)
    end
end

function M.toggle()
    if not is_vim_look then
        capture_modern_state()
        enable_vim_look(true)
        write_persisted_state(true)
    else
        if is_tty_mode then
            disable_tty_mode(false)
            write_tty_persisted_state(false)
        end
        disable_vim_look(true)
        write_persisted_state(false)
    end
end

function M.toggle_tty()
    local in_tty = is_tty_environment()
    if not is_tty_mode then
        capture_modern_state()
        enable_tty_mode(true)
        if in_tty then
            -- Restored default TTY behavior in a TTY; clear manual override
            pcall(os.remove, tty_state_file)
        else
            -- Explicitly forced TTY mode in a non-TTY environment
            write_tty_persisted_state(true)
        end
    else
        disable_tty_mode(true)
        if not in_tty then
            -- Restored default GUI behavior in non-TTY; clear manual override
            pcall(os.remove, tty_state_file)
        else
            -- Explicitly disabled TTY mode in a TTY environment
            write_tty_persisted_state(false)
        end
    end
end

vim.api.nvim_create_user_command("ToggleVimLook", M.toggle, {
    desc = "Toggle between classic Vim look and modern Neovim look (persisted)",
})

vim.api.nvim_create_user_command("ToggleTTY", M.toggle_tty, {
    desc = "Toggle TTY-compatible classic Vim mode with pure-ASCII icons/borders (persisted/automatic)",
})

-- Check persisted / auto-detected state on startup
local should_enable_tty = should_enable_tty_on_startup()
local should_enable_vim = read_persisted_state()

if should_enable_tty then
    capture_modern_state()
    enable_tty_mode(false)

    vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
            if is_tty_mode then
                enable_tty_mode(false)
            end
        end,
    })
elseif should_enable_vim then
    capture_modern_state()
    enable_vim_look(false)

    vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
            if is_vim_look then
                enable_vim_look(false)
            end
        end,
    })
end

return M
