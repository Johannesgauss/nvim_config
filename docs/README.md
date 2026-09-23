# Neovim Configuration Documentation

Welcome to the comprehensive documentation for this Neovim configuration. This documentation covers every module, setting, keybinding, UI component, plugin specification, and AI integration present in the codebase.

---

## Table of Contents

| Document | Description |
| :--- | :--- |
| [Architecture & Lifecycle](file:///home/cloud/.config/nvim/docs/architecture.md) | High-level system design, bootstrap mechanism via `lazy.nvim`, initialization sequence, and directory topology. |
| [Core Configuration](file:///home/cloud/.config/nvim/docs/core-configuration.md) | Editor options (indentation, tabs, splits, clipboard) and core global keybindings (terminals, window navigation, lazygit). |
| [UI & Appearance](file:///home/cloud/.config/nvim/docs/ui-and-appearance.md) | Catppuccin Mocha theme, custom dynamic statusline, and the persistent `:ToggleVimLook` classic Vim appearance engine. |
| [Plugins & Extensions](file:///home/cloud/.config/nvim/docs/plugins.md) | Detailed specifications and configuration for Nvim-Tree (with NERDTree emulation), Diffview, Autopairs, and Treesitter. |
| [LSP & Autocompletion](file:///home/cloud/.config/nvim/docs/lsp-and-completion.md) | Language Server Protocol (`mason`, `lspconfig`), configured language servers (`ts_ls`, `clangd`, `pyright`), diagnostics, and `nvim-cmp`. |
| [AI Integrations](file:///home/cloud/.config/nvim/docs/ai-integrations.md) | AI assistant panels and completions: Google Antigravity CLI, Claude Code, GitHub Copilot (with privacy guard), and Ollama/Minuet. |
| [Keymaps Quick Reference](file:///home/cloud/.config/nvim/docs/keymaps-reference.md) | Complete reference cheat sheet of all keybindings organized by mode and functional category. |

---

## Quick Start & Directory Tree

The configuration follows standard Neovim Lua conventions rooted at `~/.config/nvim/`:

```text
~/.config/nvim/
├── init.lua                      # Root entry point & lazy bootstrap
├── lazy-lock.json                # Plugin version pin lockfile
├── README.md                     # Root summary
├── docs/                         # Full documentation suite
│   ├── README.md                 # Documentation index (this file)
│   ├── architecture.md           # System design & lifecycle
│   ├── core-configuration.md     # Editor options & global maps
│   ├── ui-and-appearance.md      # Theme, statusline, & Vim look
│   ├── plugins.md                # Treesitter, Tree, Diffview, Autopairs
│   ├── lsp-and-completion.md     # Mason, LSP servers, nvim-cmp
│   ├── ai-integrations.md        # Antigravity, Claude, Copilot, Ollama
│   └── keymaps-reference.md      # Master keymap cheat sheet
└── lua/
    ├── init.lua (optional)
    ├── core/
    │   ├── options.lua           # Global vim options (tabs, numbers, etc.)
    │   ├── keymaps.lua           # Core navigation & terminal keymaps
    │   └── plugins-nerdtree.lua  # Fallback tree bootstrap
    ├── plugins/
    │   ├── theme.lua             # Catppuccin theme configuration
    │   ├── tree.lua              # Nvim-Tree with NERDTree mappings
    │   ├── treesitter.lua        # Syntax highlighting
    │   ├── autopairs.lua         # Pair auto-closing
    │   ├── diffview.lua          # Git diff visualizer & interactive staging
    │   └── lsp.lua               # Mason, LSP servers, nvim-cmp
    ├── ui/
    │   ├── statusline.lua        # Git-aware custom statusline
    │   └── vim_look.lua          # Persistent :ToggleVimLook engine
    └── ai/
        ├── init.lua              # AI module spec aggregator
        ├── antigravity.lua       # Antigravity panel & diffview toggles
        ├── claudecode.lua        # Claude Code terminal panel & resizer
        ├── copilot.lua           # Copilot & CopilotChat with privacy filters
        ├── local_autocomplete.lua# Minuet-AI Ollama autocomplete specs
        └── ollama.lua            # Minuet model switcher & setup
```
