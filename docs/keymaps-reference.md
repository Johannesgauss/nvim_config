# Keymaps Quick Reference

This cheat sheet compiles all keybindings across the configuration, grouped by function and mode.

> **Leader Key**: `<leader>` is mapped to `<Space>`.

---

## 1. General & Escape Motions

| Mode | Shortcut | Command / Target | Description |
| :---: | :--- | :--- | :--- |
| **Insert** | `jk` | `<Esc>` | Quickly exit insert mode without reaching for Escape. |
| **Terminal** | `jk` | `<C-\><C-n>` | Switch terminal from insert mode to normal mode. |

---

## 2. Window Navigation & Splits

| Mode | Shortcut | Action | Description |
| :---: | :--- | :--- | :--- |
| **Normal** | `<C-h>` | `<C-w>h` | Focus the window to the left. |
| **Normal** | `<C-l>` | `<C-w>l` | Focus the window to the right. |
| **Terminal** | `<C-h>` | Jump left | Exit terminal insert mode and jump to window on the left. |
| **Terminal** | `<C-l>` | Jump right | Exit terminal insert mode and jump to window on the right. |
| **Terminal** | `<C-k>` | Jump up | Exit terminal insert mode and jump to window above. |

---

## 3. Terminal & Tools

| Mode | Shortcut | Command / Target | Description |
| :---: | :--- | :--- | :--- |
| **Normal / Term** | `<C-j>` | `toggle_terminal()` | Toggle persistent bottom terminal (20% height). |
| **Normal** | `<leader>gg` | Lazygit | Open Lazygit in a dedicated fullscreen tab. |
| **Normal** | `<leader>n` | `:NvimTreeToggle<CR>` | Toggle the file explorer tree sidebar. |

---

## 4. File Tree Explorer (`nvim-tree`)

*Active when focus is inside the Nvim-Tree buffer:*

| Key | Description |
| :---: | :--- |
| `o` | Open file or expand/collapse directory folder. |
| `go` | Open file in background (keep focus inside tree). |
| `t` | Open file in a new tabpage. |
| `T` | Open file in a new tabpage in background. |
| `i` | Open file in horizontal split. |
| `gi` | Open file in horizontal split in background. |
| `s` | Open file in vertical split. |
| `gs` | Open file in vertical split in background. |
| `p` | Navigate cursor to parent directory. |
| `P` | Close / collapse parent directory. |
| `C` | Change tree root to selected directory. |
| `u` | Change tree root up one directory level. |
| `r` / `R` | Refresh tree filesystem view. |
| `I` | Toggle visibility of hidden files (dotfiles). |
| `cd` | Change Neovim working directory (`:cd`) to selected folder. |
| `?` | Toggle keymap help window. |

---

## 5. Git & Diffview

| Mode | Shortcut | Command / Action | Description |
| :---: | :--- | :--- | :--- |
| **Normal** | `<leader>gd` | `:DiffviewOpen` | Open interactive side-by-side diff view. |
| **Normal** | `<leader>gc` | `:DiffviewClose` | Close diff view and restore previous windows. |
| **Normal** | `<leader>gh` | `:DiffviewFileHistory %` | View commit history for the current buffer. |
| **Normal** | `<leader>gH` | `:DiffviewFileHistory` | View commit history for the whole repository. |
| **Normal / Visual** | `s` *(in Diffview)* | Stage Hunk / Range | Stage current hunk or visually selected lines (`git add`). |

---

## 6. LSP & Diagnostics

| Mode | Shortcut | Target Function | Description |
| :---: | :--- | :--- | :--- |
| **Normal** | `gd` | `vim.lsp.buf.definition` | Jump to symbol definition. |
| **Normal** | `gD` | `vim.lsp.buf.declaration` | Jump to symbol declaration. |
| **Normal** | `gi` | `vim.lsp.buf.implementation` | Jump to symbol implementation. |
| **Normal** | `gr` | `vim.lsp.buf.references` | Show all references across project. |
| **Normal** | `K` | `vim.lsp.buf.hover` | Display hover documentation popup. |
| **Normal** | `<C-k>` | `vim.lsp.buf.signature_help` | Display function signature helper. |
| **Normal** | `<leader>rn` | `vim.lsp.buf.rename` | Rename symbol across project. |
| **Normal** | `<leader>ca` | `vim.lsp.buf.code_action` | Show and execute code actions / fixes. |
| **Normal** | `[d` | `vim.diagnostic.goto_prev` | Jump to previous diagnostic error/warning. |
| **Normal** | `]d` | `vim.diagnostic.goto_next` | Jump to next diagnostic error/warning. |
| **Normal** | `<leader>d` | `vim.diagnostic.open_float` | Show full diagnostic details in popup. |
| **Normal** | `<leader>q` | `vim.diagnostic.setloclist` | Populate diagnostics to location list. |

---

## 7. Autocompletion (`nvim-cmp`)

| Mode | Shortcut | Description |
| :---: | :--- | :--- |
| **Insert** | `<C-j>` | Select next suggestion in menu. |
| **Insert** | `<C-k>` | Select previous suggestion in menu. |
| **Insert** | `<C-b>` | Scroll documentation upward. |
| **Insert** | `<C-f>` | Scroll documentation downward. |
| **Insert** | `<C-Space>` | Manually trigger completion popup. |
| **Insert** | `<C-e>` | Dismiss / abort completion menu. |
| **Insert** | `<CR>` | Accept and insert highlighted completion. |
| **Insert** | `<Tab>` | Accept selection or jump to next snippet placeholder. |
| **Insert** | `<S-Tab>` | Jump to previous snippet placeholder. |
| **Insert** | `<M-e>` *(autopairs)* | Fast-wrap cursor word in brackets/quotes. |

---

## 8. AI Assistants & Autocomplete

### Google Antigravity
| Mode | Shortcut | Description |
| :---: | :--- | :--- |
| **Normal** | `<leader>ai` | Toggle Antigravity CLI terminal panel (25% split). |
| **Normal** | `<leader>ad` | Toggle Diffview to inspect agent code modifications. |
| **Normal** | `<leader>as` | Resize Antigravity panel to 25% width. |
| **Normal** | `<leader>am` | Resize Antigravity panel to 42% width. |
| **Normal** | `<leader>al` | Resize Antigravity panel to 65% width. |

### Claude Code
| Mode | Shortcut | Description |
| :---: | :--- | :--- |
| **Normal** | `<leader>ci` | Toggle Claude Code terminal panel. |
| **Normal / Term** | `<leader>cs` | Resize Claude panel to 25% width. |
| **Normal / Term** | `<leader>ce` | Resize Claude panel to 65% width. |
| **Normal / Term** | `<leader>ct` | Resize Claude panel to 100% width. |

### Local Ollama / Minuet Autocomplete
| Mode | Shortcut | Description |
| :---: | :--- | :--- |
| **Insert** | `<C-y>` | Manually trigger local Ollama code completion. |
| **Normal** | `<leader>os` | Toggle between 1.5b and 7b local completion models. |

---

## 9. Custom User Commands

| Command | Description |
| :--- | :--- |
| `:ToggleVimLook` | Toggles between classic Vim look (16 ANSI colors, `colorscheme vim`, `notermguicolors`, no signcolumn) and modern look (`catppuccin-mocha`, truecolor, statusline icons). Choice is persisted across restarts. |
| `:CopilotStart` | Validates directory safety whitelist and initializes GitHub Copilot and CopilotChat. |
| `:DiffviewOpen` | Opens the Git diff split viewer. |
| `:DiffviewClose` | Closes active Git diff viewer. |
| `:DiffviewFileHistory` | Opens interactive Git log commit history. |
