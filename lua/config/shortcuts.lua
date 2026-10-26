-- ============================================================================
-- CENTRAL SHORTCUTS CONFIGURATION
-- ============================================================================
-- All keybindings across the entire Neovim setup in one simple, readable file.
-- NO JSON! Pure declarative list.
--
-- Format:
--   { "<key>", "<action>", desc = "<description>", mode = "<mode>" }
--
--   - mode: "n" (Normal, default), "i" (Insert), "t" (Terminal), "v" (Visual)
--   - action: Vim command string, key sequence, or named action dispatcher
-- ============================================================================

return {
  -- --------------------------------------------------------------------------
  -- 1. Core Navigation & Window Splits
  -- --------------------------------------------------------------------------
  { "jk", "<Esc>", desc = "Sair do modo de inserção", mode = "i" },
  { "jk", [[<C-\><C-n>]], desc = "Sair do modo terminal", mode = "t" },
  { "<C-h>", [[<C-\><C-n><C-w>h]], desc = "Sair do terminal para a esquerda", mode = "t" },
  { "<C-l>", [[<C-\><C-n><C-w>l]], desc = "Sair do terminal para a direita", mode = "t" },
  { "<C-k>", [[<C-\><C-n><C-w>k]], desc = "Sair do terminal para cima", mode = "t" },
  { "<C-h>", "<C-w>h", desc = "Mover para a janela da esquerda" },
  { "<C-l>", "<C-w>l", desc = "Mover para a janela da direita" },
  { "<C-j>", "terminal:toggle", desc = "Alternar terminal inferior", mode = { "n", "t" } },

  -- --------------------------------------------------------------------------
  -- 2. File Explorer & Lazygit
  -- --------------------------------------------------------------------------
  { "<leader>n", ":NvimTreeToggle<CR>", desc = "Alternar árvore de arquivos" },
  { "<leader>gg", "lazygit:open", desc = "Abrir Lazygit em tela cheia" },

  -- --------------------------------------------------------------------------
  -- 3. Fuzzy Search & Project Navigation (Telescope)
  -- --------------------------------------------------------------------------
  { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Buscar arquivos por nome" },
  { "<leader>f", "<cmd>Telescope find_files<CR>", desc = "Buscar arquivos por nome" },
  { "<leader>F", "<cmd>Telescope live_grep<CR>", desc = "Buscar texto em todo o projeto" },
  { "<leader>fs", "<cmd>Telescope grep_string<CR>", desc = "Buscar palavra sob o cursor" },
  { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Listar buffers abertos" },
  { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Buscar documentação e ajuda" },

  -- --------------------------------------------------------------------------
  -- 4. Git Diffview
  -- --------------------------------------------------------------------------
  { "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "Abrir visualizador de diff Git" },
  { "<leader>gc", "<cmd>DiffviewClose<CR>", desc = "Fechar visualizador de diff Git" },
  { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "Histórico Git do arquivo atual" },

  -- --------------------------------------------------------------------------
  -- 5. Markdown Viewing & LaTeX Math
  -- --------------------------------------------------------------------------
  { "<leader>mv", "markdown:toggle_view", desc = "Alternar Modo Leitor de Markdown" },
  { "<leader>mr", "markdown:toggle_render", desc = "Alternar renderização inline de Markdown" },
  { "<leader>lp", "latex:popup", desc = "LaTeX: Exibir fórmula sob o cursor em popup 2D" },
  { "<leader>mp", "latex:popup", desc = "Markdown: Exibir fórmula sob o cursor em popup 2D" },
  { "<leader>lv", "latex:toggle_virt", desc = "LaTeX: Alternar fórmulas 2D em linhas virtuais" },

  -- --------------------------------------------------------------------------
  -- 6. Appearance & Retro UI Modes
  -- --------------------------------------------------------------------------
  { "<leader>tt", "<cmd>ToggleTTY<CR>", desc = "Alternar modo TTY clássico (Linux console)" },
  { "<leader>tv", "<cmd>ToggleVimLook<CR>", desc = "Alternar entre visual Vim clássico e moderno" },

  -- --------------------------------------------------------------------------
  -- 7. LSP Diagnostics & Quick Docs
  -- --------------------------------------------------------------------------
  { "ge", "lsp:diagnostic_float", desc = "Exibir mensagem de erro/diagnóstico em float" },
  { "<C-k>", "lsp:hover_doc", desc = "Exibir documentação da função (LSP ou Ajuda)" },

  -- --------------------------------------------------------------------------
  -- 8. AI Assistants & Autocomplete
  -- --------------------------------------------------------------------------
  -- Google Antigravity
  { "<leader>ai", "ai:antigravity_toggle", desc = "Alternar painel do Google Antigravity" },
  { "<leader>ad", "ai:antigravity_diffview", desc = "Alternar Diffview do Antigravity" },

  -- Claude Code
  { "<leader>ci", "ai:claude_toggle", desc = "Alternar painel do Claude Code" },

  -- GitHub Copilot
  { "<leader>cc", "ai:copilot_chat", desc = "Alternar Copilot Chat", mode = { "n", "v" } },
  { "<leader>cr", "ai:copilot_reset", desc = "Reiniciar Copilot Chat" },

  -- Local Ollama
  { "<C-y>", "ai:ollama_complete", desc = "Disparar autocompletar local do Ollama", mode = "i" },
  { "<leader>os", "ai:ollama_model_swap", desc = "Alternar modelo local do Ollama (1.5b / 7b)" },
}
