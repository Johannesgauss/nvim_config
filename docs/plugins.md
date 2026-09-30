# Plugins & Extensions

This document details the configuration, keybindings, and behaviors of the editor's core utility plugins: Nvim-Tree, Diffview, Autopairs, and Treesitter.

---

## 1. File Explorer (`lua/plugins/tree.lua`)

The file tree is powered by [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua) and configured in [`lua/plugins/tree.lua`](file:///home/cloud/.config/nvim/lua/plugins/tree.lua).

### NERDTree Emulation Keybindings
The default `nvim-tree` mappings have been customized to emulate traditional NERDTree workflows while taking advantage of `nvim-tree.api`:

| Key | Action | Description |
| :---: | :--- | :--- |
| `o` | Open / Toggle | Opens the selected file in the main window or expands/collapses a folder. |
| `go` | Open Silent | Opens the file in the background while keeping focus inside the file tree. |
| `t` | Open New Tab | Opens the selected file in a brand-new tabpage. |
| `T` | Open Tab Silent | Opens the file in a new tabpage while keeping focus inside the tree. |
| `i` | Horizontal Split | Opens the selected file in a horizontal split window. |
| `gi` | Horizontal Split Silent | Opens in a horizontal split window while keeping focus inside the tree. |
| `s` | Vertical Split | Opens the selected file in a vertical split window. |
| `gs` | Vertical Split Silent | Opens in a vertical split window while keeping focus inside the tree. |
| `p` | Parent Directory | Moves cursor to the parent directory node. |
| `P` | Close Directory | Collapses the parent directory / returns to root node. |
| `C` | Root to Node | Sets the tree's root directory to the folder currently under the cursor. |
| `u` | Root Up | Navigates the tree's root up one directory level. |
| `r` / `R` | Refresh | Reloads and updates the file tree from the filesystem. |
| `I` | Toggle Dotfiles | Shows or hides hidden files (dotfiles). |
| `cd` | Change CWD | Sets Neovim's global current working directory (`:cd`) to the selected folder. |
| `?` | Help | Toggles the interactive `nvim-tree` keymap help overlay. |

### Tree Display Settings
- **Width**: Fixed at 30 columns on the `left` side.
- **Line Numbers**: Both `number` and `relativenumber` are enabled directly inside the tree window. This allows rapid relative jumping using standard motions (e.g. `14j`, `6k`) to land precisely on target directory entries.
- **Git Integration**: Files display Git modification markers and status highlights.
- **Filters**: `.git` directory is hidden by default (`custom = { "^\\.git$" }`).

---

## 2. Git Diff & Interactive Staging (`lua/plugins/diffview.lua`)

Git diff visual comparison and interactive staging are handled by [diffview.nvim](https://github.com/sindrets/diffview.nvim) in [`lua/plugins/diffview.lua`](file:///home/cloud/.config/nvim/lua/plugins/diffview.lua).

### Commands & Global Shortcuts
| Keymap | Command | Description |
| :--- | :--- | :--- |
| `<leader>gd` | `:DiffviewOpen` | Opens the side-by-side diff view of uncommitted changes. |
| `<leader>gc` | `:DiffviewClose` | Closes active diff view and restores normal window layout. |
| `<leader>gh` | `:DiffviewFileHistory %` | Displays commit history for the current active file. |
| `<leader>gH` | `:DiffviewFileHistory` | Displays full repository branch commit history. |

### Advanced Interactive Staging (`s`)
Inside any Diffview window, pressing `s` (in Normal or Visual mode) stages changes directly:
- **Index Buffer Detection**: Automatically identifies if the cursor is in the Git index buffer or working tree buffer.
- **Visual Selection Staging**: If lines are selected in Visual mode (`v` or `V`), pressing `s` runs an isolated `diffput`/`diffget` for only the selected range.
- **Auto Write & Refresh**: Flushes modified index buffers to disk and triggers `:DiffviewRefresh` so changes reflect immediately in Git without leaving Neovim.

---

## 3. Autopairs (`lua/plugins/autopairs.lua`)

Automated pair closing is provided by [windwp/nvim-autopairs](https://github.com/windwp/nvim-autopairs) in [`lua/plugins/autopairs.lua`](file:///home/cloud/.config/nvim/lua/plugins/autopairs.lua).

### Features
- **Lazy Event Loading**: Loaded on `InsertEnter` to ensure zero startup latency.
- **Treesitter Validation (`check_ts = true`)**: Prevents undesirable closing of quotes or brackets when typing inside strings or code comments.
- **Ignored Buffers**: Automatically disabled in search prompts (`TelescopePrompt`, `spectre_panel`).
- **Fast Wrap (`<M-e>`)**: In Insert mode, pressing <kbd>Alt</kbd>+<kbd>e</kbd> enables fast wrap mode, allowing you to instantly wrap surrounding text or identifiers in `{`, `[`, `(`, `"`, or `'`.

---

## 4. Syntax Highlighting (`lua/plugins/treesitter.lua`)

Abstract Syntax Tree (AST) parsing and semantic highlighting are driven by [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) in [`lua/plugins/treesitter.lua`](file:///home/cloud/.config/nvim/lua/plugins/treesitter.lua).

### Installed Parsers
- `prisma` (Schema modeling)
- `lua` (Neovim configuration & plugins)
- `vim` & `vimdoc` (Vimscript & documentation)
- `markdown` & `markdown_inline` (Notes and documentation)

### Highlighting
Syntax highlighting is enabled globally via AST token parsing, providing accurate highlighting and indentation rules even across complex, nested syntax structures.

### Compatibility Engine (Neovim 0.12+)
Includes an automated runtime compatibility shim in [`lua/plugins/treesitter.lua`](file:///home/cloud/.config/nvim/lua/plugins/treesitter.lua) that reconciles tree-sitter query capture structures between Neovim 0.12+ (which passes `TSNode[]` lists to directives and predicates) and `nvim-treesitter` (`master` branch). This prevents decoration provider errors (`conceal_line` / `get_range`) during markdown parsing and hover documentation popups.
