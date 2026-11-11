-- ============================================================================
-- Optional Feature Flags Loader (lua/core/features.lua)
-- ============================================================================
-- Reads ~/.config/nvim/features.conf to determine which optional modules
-- (markdown, latex, docx) are enabled.
-- ============================================================================
local M = {}

local defaults = {
    markdown = true,
    latex = true,
    docx = true,
}

local state = nil

function M.load()
    state = vim.deepcopy(defaults)
    local conf_path = vim.fs.joinpath(vim.fn.stdpath("config"), "features.conf")
    if vim.fn.filereadable(conf_path) ~= 1 then
        return state
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
                val = vim.trim(val):lower()
                if val == "true" or val == "1" or val == "yes" or val == "on" then
                    state[key] = true
                elseif val == "false" or val == "0" or val == "no" or val == "off" then
                    state[key] = false
                end
            end
        end
    end
    return state
end

function M.is_enabled(feature)
    if not state then
        M.load()
    end
    return state[feature] == true
end

function M.get_all()
    if not state then
        M.load()
    end
    return vim.deepcopy(state)
end

function M.set(feature, enabled)
    if not state then
        M.load()
    end
    feature = feature:lower()
    if state[feature] == nil then
        vim.notify("Unknown feature: " .. feature, vim.log.levels.ERROR)
        return false
    end
    state[feature] = enabled and true or false

    local conf_path = vim.fs.joinpath(vim.fn.stdpath("config"), "features.conf")
    if vim.fn.filereadable(conf_path) == 1 then
        local lines = vim.fn.readfile(conf_path)
        local updated = false
        for i, line in ipairs(lines) do
            if line:match("^%s*" .. vim.pesc(feature) .. "%s*=") then
                lines[i] = line:gsub("(=%s*)%a+", "%1" .. tostring(state[feature]), 1)
                updated = true
            end
        end
        if not updated then
            table.insert(lines, string.format("%-8s = %s", feature, tostring(state[feature])))
        end
        pcall(vim.fn.writefile, lines, conf_path)
    end
    return true
end

return M
