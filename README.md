# Neovim Configuration

A modular Neovim setup using [lazy.nvim](https://github.com/folke/lazy.nvim) for plugin management.

## Structure

```text
~/.config/nvim
├── init.lua             # Entry point & lazy.nvim bootstrap
├── lua/
│   ├── core/           # Core configuration (options & global keymaps)
│   ├── plugins/        # Plugin specifications & configurations (LSP, treesitter, etc.)
│   ├── ui/             # Custom UI elements (statusline)
│   └── ai/             # AI assistant and completion integrations
└── .gitignore
```

## Features

- **Package Manager**: [lazy.nvim](https://github.com/folke/lazy.nvim)
- **LSP & Completion**: Native Neovim LSP, [mason.nvim](https://github.com/williamboman/mason.nvim), [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- **Syntax**: [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- **File Explorer**: [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua)
- **Git Integration**: [diffview.nvim](https://github.com/sindrets/diffview.nvim) & Lazygit integration
- **Theme**: [Catppuccin Mocha](https://github.com/catppuccin/nvim)
- **AI Integrations**: Antigravity, Claude Code, GitHub Copilot, and Ollama support

## Documentation

Full documentation is available in the [`docs/`](docs/README.md) directory:

- [Architecture & Lifecycle](docs/architecture.md)
- [Core Configuration & Options](docs/core-configuration.md)
- [UI, Statusline & :ToggleVimLook](docs/ui-and-appearance.md)
- [Plugins (Tree, Diffview, Autopairs, Treesitter)](docs/plugins.md)
- [LSP & Autocompletion](docs/lsp-and-completion.md)
- [AI Integrations (Antigravity, Claude, Copilot, Ollama)](docs/ai-integrations.md)
- [Keymaps Cheat Sheet](docs/keymaps-reference.md)
