# LSP & Autocompletion

This document explains the Language Server Protocol (LSP) setup, Mason package manager, language server configurations, diagnostic formatting, and `nvim-cmp` autocompletion engine located in [`lua/plugins/lsp.lua`](file:///home/cloud/.config/nvim/lua/plugins/lsp.lua).

---

## 1. Package Management (`mason.nvim`)

[mason.nvim](https://github.com/williamboman/mason.nvim) manages external language servers, formatters, and linters directly from within Neovim.

- **Status Icons**:
  - `✓` Installed
  - `➜` Pending
  - `✗` Uninstalled
- **Bridge (`mason-lspconfig.nvim`)**: Automatically ensures the following language servers are installed:
  - `ts_ls` (TypeScript & JavaScript)
  - `clangd` (C and C++)
  - `lua_ls` (Lua & Neovim API runtime)
  - `pyright` (Python)

---

## 2. Configured Language Servers

The native Neovim LSP client is configured via [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig):

| Server | Languages | Custom Configuration / Features |
| :--- | :--- | :--- |
| **`ts_ls`** | TypeScript, JavaScript, JSX, TSX | Standard capabilities bridged to `cmp-nvim-lsp`. |
| **`clangd`** | C, C++ | Standard compilation database and header indexing. |
| **`pyright`** | Python | Configured with `autoSearchPaths = true`, `useLibraryCodeForTypes = true`, and `diagnosticMode = "workspace"`. |
| **`lua_ls`** | Lua, Neovim Configs | Configured with `LuaJIT` runtime, `vim` globals, and Neovim runtime library awareness. |

---

## 3. LSP Keybindings (`LspAttach`)

When a language server attaches to an active buffer, a dedicated `LspAttach` autocmd registers buffer-local keymaps:

| Keymap | Action | Description |
| :--- | :--- | :--- |
| `gd` | Definition | Jump to the symbol definition (`vim.lsp.buf.definition`). |
| `gD` | Declaration | Jump to the symbol declaration (`vim.lsp.buf.declaration`). |
| `gi` | Implementation | List all implementations of an interface/method (`vim.lsp.buf.implementation`). |
| `gr` | References | Find all symbol references throughout the project (`vim.lsp.buf.references`). |
| `K` | Hover Documentation | Show hover doc popup / type signature (`vim.lsp.buf.hover`). |
| `<C-k>` | Hover Documentation | Show hover doc popup / function documentation (`vim.lsp.buf.hover`). |
| `<C-s>` | Signature Help | Show function arguments reminder popup in Normal and Insert mode (`vim.lsp.buf.signature_help`). |
| `<leader>k` | Signature Help | Show function arguments reminder popup in Normal mode (`vim.lsp.buf.signature_help`). |
| `<leader>th` | Toggle Inlay Hints | Toggle inline argument name / type hints on and off (`vim.lsp.inlay_hint`). |
| `<leader>rn` | Rename Symbol | Project-wide symbol rename (`vim.lsp.buf.rename`). |
| `<leader>ca` | Code Actions | Display and apply available code fixes/refactors (`vim.lsp.buf.code_action`). |
| `[d` | Previous Diagnostic | Jump cursor to previous diagnostic error/warning (`vim.diagnostic.goto_prev`). |
| `]d` | Next Diagnostic | Jump cursor to next diagnostic error/warning (`vim.diagnostic.goto_next`). |
| `<leader>d` | Diagnostic Float | Open floating window with complete diagnostic error message (`vim.diagnostic.open_float`). |
| `<leader>q` | Location List | Populate buffer diagnostics into the location list window (`vim.diagnostic.setloclist`). |

### Function Arguments Reminder (VS Code Style)
- **Automatic Signature Help**: Typing `(` or `,` inside any function call automatically opens a floating window detailing the function's parameters, parameter types, docstrings, and highlighting the active argument being typed.
- **Inlay Hints**: Enabled automatically for language servers that support them, displaying parameter names directly inline before each argument (e.g., `pthread_atfork(__prepare: NULL, ...)`). Toggle anytime with `<leader>th`.
- **Manual Reminders**: Press <kbd>Ctrl</kbd>+<kbd>s</kbd> at any point in Insert or Normal mode to bring up or refresh the arguments popup.

---

## 4. Diagnostics Configuration

Diagnostics are styled with custom gutter icons and floating windows:

- **Gutter Signs**:
  - Error: `✘` (`DiagnosticSignError`)
  - Warning: `▲` (`DiagnosticSignWarn`)
  - Hint: `⚑` (`DiagnosticSignHint`)
  - Information: `»` (`DiagnosticSignInfo`)
- **Display Behavior**:
  - `virtual_text = { prefix = "●" }`: Renders concise diagnostic text inline.
  - `update_in_insert = false`: Delays diagnostic updates until exiting Insert mode to avoid visual noise while typing.
  - `severity_sort = true`: Prioritizes errors above warnings.
  - `float = { border = "rounded", source = "always" }`: Rounded borders showing the error source (e.g. `[pyright]`).

*(Note: When `:ToggleVimLook` is active, virtual text and gutter signs are cleanly suppressed for a classic distraction-free look.)*

---

## 5. Autocompletion Engine (`nvim-cmp`)

The completion pipeline is driven by [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) and [LuaSnip](https://github.com/L3MON4D3/LuaSnip).

### Sources (Priority Order)
1. `nvim_lsp`: Completions from active language servers.
2. `luasnip`: Code snippets with tab stops and expansions.
3. `buffer`: Text tokens extracted from the current active buffer.
4. `path`: Local filesystem paths for string completions.

### Completion Keymaps
| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `<C-k>` | Insert | Select previous suggestion in menu. |
| `<C-j>` | Insert | Select next suggestion in menu. |
| `<C-b>` | Insert | Scroll documentation popup up (4 lines). |
| `<C-f>` | Insert | Scroll documentation popup down (4 lines). |
| `<C-Space>` | Insert | Manually invoke completion popup menu. |
| `<C-e>` | Insert | Abort / dismiss completion menu. |
| `<CR>` (Enter) | Insert | Confirm and accept the selected completion item. |
| `<Tab>` | Insert / Select | Select next item, jump to next snippet placeholder, or fallback. |
| `<S-Tab>` | Insert / Select | Select previous item, jump to previous snippet placeholder, or fallback. |

### UI Styling
Both the completion menu and documentation popup utilize rounded bordered windows (`cmp.config.window.bordered()`).
