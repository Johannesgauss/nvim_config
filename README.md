# Neovim Configuration

A modular Neovim setup using [lazy.nvim](https://github.com/folke/lazy.nvim) for plugin management.

## Quick Installation & Update (Automated Setup)

The universal installer automatically detects your operating system and architecture (**Linux** distros including **Gentoo**, **Arch/CachyOS**, **Debian/Ubuntu**, **Fedora**, **openSUSE**, **Void**, **Alpine**, **NixOS**; **macOS ARM64 & older Intel x86_64**; **FreeBSD/OpenBSD**; and **Windows** via WSL, Git Bash, MSYS2, or PowerShell), installs all essential dependencies, asks **1 by 1** which optional tools you want before starting, clones/updates this repository in `~/.config/nvim`, and syncs all plugins and Treesitter parsers headlessly.

### Linux, macOS & UNIX (Install to `~/.local/bin` & Run)

Run the following command to install the setup script into `~/.local/bin/nvim-installer` and execute it immediately:

```bash
mkdir -p ~/.local/bin && curl -fsSL https://raw.githubusercontent.com/Johannesgauss/nvim_config/main/install.sh -o ~/.local/bin/nvim-installer && chmod +x ~/.local/bin/nvim-installer && ~/.local/bin/nvim-installer
```

*(Alternatively, using `wget`:)*
```bash
mkdir -p ~/.local/bin && wget -qO ~/.local/bin/nvim-installer https://raw.githubusercontent.com/Johannesgauss/nvim_config/main/install.sh && chmod +x ~/.local/bin/nvim-installer && ~/.local/bin/nvim-installer
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/Johannesgauss/nvim_config/main/install.ps1 | iex
```

### Updating & Managing Afterward

Once installed on UNIX systems, `nvim-installer` stays in `~/.local/bin/nvim-installer` so you can update or reconfigure at any time from anywhere:

```bash
nvim-installer --update        # Updates ~/.config/nvim, plugins, Treesitter parsers & dependencies
nvim-installer --quick-update  # Fast git pull + plugin sync only
nvim-installer                 # Interactive mode (update or add new optional tools 1-by-1)
nvim-installer --all           # Non-interactive: install essentials + all optionals
nvim-installer --minimal       # Non-interactive: install essentials only
```

---

## Structure

```text
~/.config/nvim
├── init.lua             # Entry point & lazy.nvim bootstrap
├── install.sh           # Universal cross-platform installer & updater (UNIX/Linux/macOS/Git Bash)
├── install.ps1          # Native Windows PowerShell installer & updater
├── shortcuts.conf       # Linux-style central shortcuts config (key = action)
├── lua/
│   ├── core/           # Core configuration (options & shortcuts parser)
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
| **GDB / LLDB** | Quick C/C++/Rust compilation & terminal debugging (`<leader>db`) | `gdb` or `lldb` |
| **LaTeX Tools** | Full `.tex` compilation & live PDF preview via VimTeX | `latexmk`, `texlive`, `zathura` |
| **Nerd Font** | Icons for statusline, NvimTree, and Telescope (GUI/terminal) | [JetBrains Mono Nerd Font](https://www.nerdfonts.com/) |
| **AI CLIs** | AI assistant terminal panels | `agy`, `claude`, `ollama` |

> [!TIP]
> The editor automatically checks standard paths (`~/.local/bin`, `~/.cargo/bin`, `/opt/homebrew/bin`, `/usr/local/bin`, `/opt/local/bin`) upon launch, ensuring locally compiled binaries (like `tree-sitter`, `rg`, `fd`, `nvim-installer`) are immediately accessible across all environments.

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
