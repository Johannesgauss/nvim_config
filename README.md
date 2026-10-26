# Neovim Configuration

A modular Neovim setup using [lazy.nvim](https://github.com/folke/lazy.nvim) for plugin management.

## Structure

```text
~/.config/nvim
├── init.lua             # Entry point & lazy.nvim bootstrap
├── lua/
│   ├── config/         # Central shortcuts configuration (shortcuts.lua)
│   ├── core/           # Core configuration (options & keymap loader)
│   ├── plugins/        # Plugin specifications & configurations (LSP, treesitter, etc.)
│   ├── ui/             # Custom UI elements (statusline)
│   └── ai/             # AI assistant and completion integrations
└── .gitignore
```

## Features

- **Package Manager**: [lazy.nvim](https://github.com/folke/lazy.nvim)
- **Fuzzy Finder & Search**: [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (live grep & file search)
- **LSP & Completion**: Native Neovim LSP, [mason.nvim](https://github.com/williamboman/mason.nvim), [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- **Syntax & Parsers**: [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- **Markdown & LaTeX**: In-buffer rich rendering (`render-markdown.nvim`), 2D math formula visualization (`nabla.nvim`), distraction-free reader mode, and full LaTeX authoring (`vimtex`)
- **File Explorer**: [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua) with NERDTree keybindings
- **Git Integration**: [diffview.nvim](https://github.com/sindrets/diffview.nvim) & Lazygit integration
- **Theme & Retro Look**: [Catppuccin Mocha](https://github.com/catppuccin/nvim), persistent classic 16-color Vim look (`:ToggleVimLook`), and pure-ASCII Linux virtual console compatibility (`:ToggleTTY`)
- **AI Integrations**: Antigravity, Claude Code, GitHub Copilot, and Ollama support

## Requirements & Dependencies

To ensure all plugins, treesitter parsers, search tools, and language servers function correctly, the following system tools are needed:

### Essential Core Dependencies
| Tool | Purpose | Package / Command |
| :--- | :--- | :--- |
| **Neovim** | `>= 0.10.0` editor runtime | `nvim` |
| **Git** | Package manager bootstrap & diffview | `git` |
| **C Compiler** | Compiling Treesitter parsers & native extensions | `gcc` or `clang` |
| **Make** | Building native FZF C sorter for Telescope | `make` |
| **Tree-sitter CLI** | Generating grammars from source (e.g. `latex`, ABI $\ge 15$) | `tree-sitter` (`v0.25+` in `PATH` / `~/.local/bin`) |
| **Ripgrep** | Project-wide fast regex search (`live_grep`) | `ripgrep` (`rg`) |
| **Fd** | Fast filesystem traversal for Telescope (`find_files`) | `fd-find` (`fd`) |
| **Node.js & npm** | Mason package installer for LSP servers & Copilot | `node`, `npm` |
| **Python 3** | Python LSP servers (Pyright) & scripts | `python3`, `python3-pip` |

### Optional / Workflow Dependencies
| Tool | Purpose | Package / Command |
| :--- | :--- | :--- |
| **Lazygit** | Fullscreen interactive Git terminal tab (`<leader>gg`) | `lazygit` |
| **Rust / Cargo** | Rust development & `rust-analyzer` LSP | `cargo`, `rustc` |
| **LaTeX Tools** | Full `.tex` compilation & live PDF preview via VimTeX | `latexmk`, `texlive`, `zathura` |
| **Nerd Font** | Icons for statusline, NvimTree, and Telescope (GUI/terminal) | [JetBrains Mono Nerd Font](https://www.nerdfonts.com/) |
| **AI CLIs** | AI assistant terminal panels | `agy`, `claude`, `ollama` |

> [!TIP]
> The editor automatically checks standard paths (`~/.local/bin`, `~/.cargo/bin`, `/usr/local/bin`) upon launch, ensuring locally compiled binaries (like `tree-sitter`, `rg`, `fd`) are immediately accessible across all environments.

---

## Documentation

Full documentation is available in the [`docs/`](docs/README.md) directory:

- [Architecture & Lifecycle](docs/architecture.md)
- [Core Configuration & Options](docs/core-configuration.md)
- [UI, Statusline, :ToggleVimLook, :ToggleTTY & Markdown Reader](docs/ui-and-appearance.md)
- [Plugins (Tree, Diffview, Telescope, Markdown, LaTeX, Autopairs, Treesitter)](docs/plugins.md)
- [LSP & Autocompletion](docs/lsp-and-completion.md)
- [AI Integrations (Antigravity, Claude, Copilot, Ollama)](docs/ai-integrations.md)
- [Keymaps Cheat Sheet](docs/keymaps-reference.md)
