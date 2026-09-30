local keymap = vim.keymap

-- Modo de Inserção: Atalho rápido 'jk' para voltar ao modo Normal
keymap.set("i", "jk", "<Esc>", { desc = "Sair do modo de inserção" })

-- Modo de Terminal: Atalhos de fuga rápidos
keymap.set("t", "jk", [[<C-\><C-n>]], { desc = "Sair do modo terminal" })
keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Sair do terminal para a esquerda" })
keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Sair do terminal para a direita" })
keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Sair do terminal para cima" })

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

keymap.set("n", "<C-j>", toggle_terminal, { desc = "Alternar terminal" })
keymap.set("t", "<C-j>", toggle_terminal, { desc = "Alternar terminal" })

keymap.set("n", "<leader>n", ":NvimTreeToggle<CR>", { desc = "Toggle file tree" })
-- Modo Normal: Navegação entre janelas splits
keymap.set("n", "<C-h>", "<C-w>h", { desc = "Mover para a janela da esquerda" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Mover para a janela da direita" })

-- Modo Normal: Exibir documentação da função sob o cursor (LSP ou Ajuda do Vim)
keymap.set("n", "<C-k>", function()
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
end, { desc = "Exibir documentação / ajuda" })

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
