local M = {}

local state_dir = vim.fn.stdpath("state")
local state_file = state_dir .. "/vim_look_enabled"

local is_vim_look = false
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
}

local function read_persisted_state()
    local f = io.open(state_file, "r")
    if not f then return false end
    local content = f:read("*a")
    f:close()
    if not content then return false end
    return vim.trim(content) == "true"
end

local function write_persisted_state(enabled)
    if vim.fn.isdirectory(state_dir) == 0 then
        vim.fn.mkdir(state_dir, "p")
    end
    local f = io.open(state_file, "w")
    if f then
        f:write(enabled and "true" or "false")
        f:close()
    end
end

local function apply_win_options(rnu, signcol, curline)
    vim.opt.number = true
    vim.opt.relativenumber = rnu
    vim.opt.signcolumn = signcol
    vim.opt.cursorline = curline

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
            vim.wo[win].number = true
            vim.wo[win].relativenumber = rnu
            vim.wo[win].signcolumn = signcol
            vim.wo[win].cursorline = curline
        end
    end
end

local function capture_modern_state()
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
end

local function enable_vim_look(notify)
    vim.o.termguicolors = false
    vim.cmd.colorscheme("vim")
    vim.o.statusline = "%<%f %h%m%r%=%-14.(%l,%c%V%) %P"
    vim.o.showmode = true
    vim.o.ruler = true
    vim.o.showcmd = true
    vim.opt.fillchars = { eob = "~", vert = "|" }
    apply_win_options(true, "no", false)

    pcall(vim.diagnostic.config, {
        virtual_text = false,
        signs = false,
        underline = false,
    })

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

    pcall(vim.diagnostic.config, {
        virtual_text = { prefix = "●" },
        signs = true,
        underline = true,
    })

    is_vim_look = false
    if notify then
        vim.notify("Modern look restored (remembered across restarts)", vim.log.levels.INFO)
    end
end

function M.toggle()
    if not is_vim_look then
        capture_modern_state()
        enable_vim_look(true)
        write_persisted_state(true)
    else
        disable_vim_look(true)
        write_persisted_state(false)
    end
end

vim.api.nvim_create_user_command("ToggleVimLook", M.toggle, {
    desc = "Toggle between classic Vim look and modern Neovim look (persisted)",
})

-- Check persisted state on startup
local should_enable = read_persisted_state()
if should_enable then
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
