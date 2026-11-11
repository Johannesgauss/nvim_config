return {
    "windwp/nvim-autopairs",
    event = "InsertEnter", -- Load the plugin upon entering insert mode
    config = function()
        require("nvim-autopairs").setup({
            check_ts = true, -- Treesitter integration to avoid faulty closings in strings or comments
            disable_filetype = { "TelescopePrompt", "spectre_panel" }, -- Disable in search and prompt panels
            fast_wrap = {
                map = "<M-e>", -- Alt + e to quickly wrap existing word/characters with pairs
                chars = { "{", "[", "(", '"', "'" },
                pattern = [=[[%'%"%)%]%}%s]=],
                end_key = "$",
                keys = "qwertyuiopzxcvbnmasdfghjkl",
                check_comma = true,
                highlight = "Search",
                highlight_grey = "Comment"
            },
        })
    end
}
