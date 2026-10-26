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
end, { desc = "Alternar modo TTY clássico com bordas ASCII" })

vim.api.nvim_create_user_command("ToggleVimLook", function()
    require("ui.vim_look").toggle()
end, { desc = "Alternar entre visual Vim clássico e moderno" })

vim.api.nvim_create_user_command("ToggleMarkdownView", function()
    require("ui.markdown_view").toggle()
end, { desc = "Alternar Modo Leitor de Markdown (Distraction-Free)" })

-- ============================================================================
-- Load & Register Central Shortcuts (lua/config/shortcuts.lua)
-- ============================================================================
local ok_shortcuts, shortcuts = pcall(require, "config.shortcuts")
if ok_shortcuts and type(shortcuts) == "table" then
    for _, item in ipairs(shortcuts) do
        local key = item[1] or item.key
        local target = item[2] or item.action
        local mode = item.mode or "n"
        local desc = item.desc or ""

        if key and target then
            local handler
            if type(target) == "function" then
                handler = target
            elseif type(target) == "string" and actions[target] then
                handler = actions[target]
            else
                handler = target
            end

            keymap.set(mode, key, handler, {
                desc = desc,
                silent = true,
            })
        end
    end
end
