-- ============================================================================
-- Optional Modules Loader & Registry (lua/modules/init.lua)
-- ============================================================================
-- Coordinates optional authoring features (markdown, latex, docx) based on
-- features.conf so disabled features add zero startup or runtime bloat.
-- ============================================================================
local features = require("core.features")

local M = {}

local available_modules = {
    "markdown",
    "latex",
    "docx",
}

--- Returns Lazy.nvim plugin specs for all enabled optional modules
function M.plugins()
    local specs = {}
    for _, name in ipairs(available_modules) do
        if features.is_enabled(name) then
            local ok, mod = pcall(require, "modules." .. name)
            if ok and mod and type(mod.plugins) == "table" then
                for _, spec in ipairs(mod.plugins) do
                    table.insert(specs, spec)
                end
            end
        end
    end
    return specs
end

--- Collects action handlers from all enabled optional modules
function M.actions()
    local act = {}
    for _, name in ipairs(available_modules) do
        if features.is_enabled(name) then
            local ok, mod = pcall(require, "modules." .. name)
            if ok and mod and type(mod.actions) == "table" then
                for k, fn in pairs(mod.actions) do
                    act[k] = fn
                end
            end
        end
    end
    return act
end

--- Runs setup() for all enabled optional modules and registers :Features commands
function M.setup()
    for _, name in ipairs(available_modules) do
        if features.is_enabled(name) then
            local ok, mod = pcall(require, "modules." .. name)
            if ok and mod and type(mod.setup) == "function" then
                mod.setup()
            end
        end
    end

    vim.api.nvim_create_user_command("Features", function()
        local all = features.get_all()
        local lines = { "Optional Features (features.conf):" }
        for _, name in ipairs(available_modules) do
            table.insert(lines, string.format("  %-10s = %s", name, all[name] and "enabled" or "disabled"))
        end
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    end, { desc = "Show status of optional modules (markdown, latex, docx)" })

    vim.api.nvim_create_user_command("FeatureToggle", function(opts)
        local name = vim.trim(opts.args or ""):lower()
        if name == "" then
            vim.cmd("Features")
            return
        end
        local next_val = not features.is_enabled(name)
        if features.set(name, next_val) then
            vim.notify(
                string.format("Feature '%s' %s in features.conf (restart Neovim to fully unload/load plugins)", name, next_val and "enabled" or "disabled"),
                vim.log.levels.INFO
            )
        end
    end, {
        nargs = "?",
        complete = function()
            return available_modules
        end,
        desc = "Toggle an optional feature in features.conf (:FeatureToggle [markdown|latex|docx])",
    })
end

return M
