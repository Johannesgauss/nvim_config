local keymap = vim.keymap

-- Modo de Inserção: Atalho rápido 'jk' para voltar ao modo Normal
keymap.set("i", "jk", "<Esc>", { desc = "Sair do modo de inserção" })

-- Modo de Terminal: Atalhos de fuga rápidos
keymap.set("t", "jk", [[<C-\><C-n>]], { desc = "Sair do modo terminal" })
keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Sair do terminal para a esquerda" })
keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Sair do terminal para a direita" })
keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], { desc = "Sair do terminal para baixo" })
keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Sair do terminal para cima" })
keymap.set("n", "<leader>n", ":NvimTreeToggle<CR>", { desc = "Toggle file tree" })
-- Modo Normal: Navegação entre janelas splits
keymap.set("n", "<C-h>", "<C-w>h", { desc = "Mover para a janela da esquerda" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Mover para a janela da direita" })

-- Integração do Lazygit em uma aba limpa e dedicada
keymap.set("n", "<leader>gg", function()
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
end, { desc = "Abrir Lazygit em Tela Cheia" })
