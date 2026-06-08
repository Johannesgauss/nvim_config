return {
    "windwp/nvim-autopairs",
    event = "InsertEnter", -- Carrega o plugin no exato momento em que você entra no modo de inserção
    config = function()
        require("nvim-autopairs").setup({
            check_ts = true, -- Integração com o Treesitter para evitar fechamentos errados dentro de strings ou comentários
            disable_filetype = { "TelescopePrompt", "spectre_panel" }, -- Desativa em painéis de busca onde atrapalharia
            fast_wrap = {
                map = "<M-e>", -- Alt + e para envolver uma palavra existente com parênteses rapidamente
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
