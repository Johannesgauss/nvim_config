local M = {}

-- Table to store saved buffer and window options per buffer ID
local saved_states = {}

--- Check if the active buffer is in reader mode
--- @param bufnr number|nil
--- @return boolean
function M.is_active(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    return vim.b[bufnr].markdown_view_active == true
end

--- Enable reader mode on a buffer
--- @param bufnr number|nil
--- @param notify boolean|nil
function M.enable(bufnr, notify)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local winnr = vim.api.nvim_get_current_win()

    if M.is_active(bufnr) then
        return
    end

    -- Capture current buffer and window options
    saved_states[bufnr] = {
        wrap = vim.wo[winnr].wrap,
        linebreak = vim.wo[winnr].linebreak,
        breakindent = vim.wo[winnr].breakindent,
        number = vim.wo[winnr].number,
        relativenumber = vim.wo[winnr].relativenumber,
        signcolumn = vim.wo[winnr].signcolumn,
        foldcolumn = vim.wo[winnr].foldcolumn,
        conceallevel = vim.wo[winnr].conceallevel,
        concealcursor = vim.wo[winnr].concealcursor,
        modifiable = vim.bo[bufnr].modifiable,
        readonly = vim.bo[bufnr].readonly,
    }

    -- Apply distraction-free reader settings
    vim.wo[winnr].wrap = true
    vim.wo[winnr].linebreak = true
    vim.wo[winnr].breakindent = true
    vim.wo[winnr].number = false
    vim.wo[winnr].relativenumber = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].foldcolumn = "0"
    vim.wo[winnr].conceallevel = 2
    vim.wo[winnr].concealcursor = "nvic"

    -- Prevent accidental edits while reading/scrolling
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].readonly = true

    -- Ensure in-buffer markdown rendering is enabled if render-markdown is present
    pcall(function()
        local rm = require("render-markdown")
        if rm and rm.enable then
            rm.enable()
        end
    end)

    -- Map 'q' to exit reader mode cleanly
    vim.keymap.set("n", "q", function()
        M.disable(bufnr, true)
    end, {
        buffer = bufnr,
        silent = true,
        desc = "Exit Markdown reader mode",
    })

    vim.b[bufnr].markdown_view_active = true

    if notify ~= false then
        vim.notify("Markdown reader mode enabled (<leader>mv or 'q' to exit)", vim.log.levels.INFO)
    end
end

--- Disable reader mode on a buffer
--- @param bufnr number|nil
--- @param notify boolean|nil
function M.disable(bufnr, notify)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local winnr = vim.api.nvim_get_current_win()

    if not M.is_active(bufnr) then
        return
    end

    local saved = saved_states[bufnr] or {}

    -- Restore modifiable / readonly attributes
    vim.bo[bufnr].modifiable = (saved.modifiable ~= nil) and saved.modifiable or true
    vim.bo[bufnr].readonly = (saved.readonly ~= nil) and saved.readonly or false

    -- Restore window layout settings
    if saved.wrap ~= nil then vim.wo[winnr].wrap = saved.wrap end
    if saved.linebreak ~= nil then vim.wo[winnr].linebreak = saved.linebreak end
    if saved.breakindent ~= nil then vim.wo[winnr].breakindent = saved.breakindent end
    if saved.number ~= nil then vim.wo[winnr].number = saved.number end
    if saved.relativenumber ~= nil then vim.wo[winnr].relativenumber = saved.relativenumber end
    if saved.signcolumn ~= nil then vim.wo[winnr].signcolumn = saved.signcolumn end
    if saved.foldcolumn ~= nil then vim.wo[winnr].foldcolumn = saved.foldcolumn end
    if saved.conceallevel ~= nil then vim.wo[winnr].conceallevel = saved.conceallevel end
    if saved.concealcursor ~= nil then vim.wo[winnr].concealcursor = saved.concealcursor end

    -- Remove buffer-local 'q' mapping
    pcall(vim.keymap.del, "n", "q", { buffer = bufnr })

    saved_states[bufnr] = nil
    vim.b[bufnr].markdown_view_active = false

    if notify ~= false then
        vim.notify("Markdown reader mode disabled; normal editing restored", vim.log.levels.INFO)
    end
end

--- Toggle reader mode on the current buffer
--- @param bufnr number|nil
function M.toggle(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if M.is_active(bufnr) then
        M.disable(bufnr, true)
    else
        M.enable(bufnr, true)
    end
end

vim.api.nvim_create_user_command("ToggleMarkdownView", function()
    M.toggle()
end, { desc = "Toggle Markdown Reader Mode (Distraction-Free)" })

return M
