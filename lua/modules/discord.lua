-- ============================================================================
-- Optional Module: Discord Rich Presence (lua/modules/discord.lua)
-- ============================================================================
-- Displays "Playing Neovim" on Discord via cord.nvim.
-- Controlled via `discord = true/false` in features.conf.
-- ============================================================================
local M = {}

M.name = "discord"

M.plugins = {
    {
        "vyfor/cord.nvim",
        build = ":Cord update",
        event = "VeryLazy",
        opts = {
            editor = {
                client = "neovim",
                tooltip = "The Superior Text Editor",
            },
            idle = {
                enabled = true,
                timeout = 300000, -- 5 minutes
            },
        },
    },
}

M.actions = {
    ["discord:toggle"] = function()
        pcall(vim.cmd, "Cord toggle")
    end,
}

return M
