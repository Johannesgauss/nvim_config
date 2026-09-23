# Architecture & Lifecycle

This document explains the runtime architecture, initialization sequence, plugin lifecycle management, and design principles of this Neovim configuration.

---

## 1. Initialization Lifecycle

When Neovim starts, [`init.lua`](file:///home/cloud/.config/nvim/init.lua) serves as the primary root orchestrator. The initialization sequence is strictly ordered:

```
[Neovim Launch]
       │
       ▼
1. require("core.options")      ──► Baseline editor options (smartindent, tabstop, clipboard)
       │
       ▼
2. require("core.keymaps")      ──► Global keybindings, terminal toggle, lazygit
       │
       ▼
3. Bootstrap lazy.nvim          ──► Checks fs_stat; clones folke/lazy.nvim if absent
       │
       ▼
4. require("lazy").setup(...)   ──► Loads lua/plugins/* and injected lua/ai specs
   ├── Theme (Catppuccin)
   ├── Treesitter
   ├── Nvim-Tree
   ├── Diffview
   ├── Autopairs
   ├── Mason / LSP / nvim-cmp
   └── AI modules (Antigravity CLI panel, etc.)
       │
       ▼
5. require("ui.statusline")     ──► Builds dynamic Git-aware statusline
       │
       ▼
6. require("ui.vim_look")       ──► Restores persisted Classic Vim or Modern state
```

### Rationale for Load Order
- **Core Options first**: Editor options such as leader keys (`vim.g.mapleader = " "`) and shell settings must be established before plugins load, as many plugins depend on `<leader>` or option flags at registration time.
- **Plugins via `lazy.nvim`**: Third-party plugins are loaded declaratively. High priority plugins (e.g. `catppuccin` with `priority = 1000`) load immediately, while lazy-loaded plugins wait for specific events (e.g. `InsertEnter` for autopairs, commands for diffview).
- **UI & Overrides last**: UI components like `statusline` and `vim_look` are registered after plugins have populated their namespaces. This guarantees that colorschemes and diagnostics settings can be cleanly inspected, applied, or overridden.

---

## 2. Package Management (`lazy.nvim`)

The setup uses [folke/lazy.nvim](https://github.com/folke/lazy.nvim) for modern, performant, asynchronous plugin management.

### Self-Bootstrapping Logic
Inside [`init.lua`](file:///home/cloud/.config/nvim/init.lua#L4-L11):
```lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
```
If a fresh system clones this repository, Neovim automatically downloads `lazy.nvim` upon first launch without manual user intervention.

### Declarative Import Pattern
The configuration mixes automatic directory imports with direct specification returns:
```lua
require("lazy").setup({
  { import = "plugins" },      -- Automatically imports all files in lua/plugins/
  require("ai"),               -- Aggregates and injects active AI specs
}, {
  change_detection = { notify = false },
})
```
- `{ import = "plugins" }` scans [`lua/plugins/`](file:///home/cloud/.config/nvim/lua/plugins/) and registers each file returning a plugin specification.
- `require("ai")` points to [`lua/ai/init.lua`](file:///home/cloud/.config/nvim/lua/ai/init.lua), allowing AI integrations to be conditionally toggled or configured modularly.

---

## 3. Persistent State Architecture

In addition to standard Neovim swap and undo files, this setup employs local state persistence:

- **Plugin Lockfile**: [`lazy-lock.json`](file:///home/cloud/.config/nvim/lazy-lock.json) pins exact Git commit SHAs for every installed plugin, ensuring deterministic environments across different machines.
- **UI State**: [`lua/ui/vim_look.lua`](file:///home/cloud/.config/nvim/lua/ui/vim_look.lua) writes its active state to `vim.fn.stdpath("state") .. "/vim_look_enabled"` (`~/.local/state/nvim/vim_look_enabled`).
  - Read synchronously on startup.
  - Re-applied on `VimEnter` once lazy plugins finish.
  - Does not pollute Git tracked repositories.

---

## 4. Coding Conventions & Design Principles

1. **Pure Lua**: All new features and configurations are authored in Lua instead of legacy Vimscript.
2. **Safe Calls**: Modules interacting with optional plugins utilize `pcall(require, ...)` to fail gracefully if dependencies are absent.
3. **Buffer-local Cleanliness**: Temporary buffers (terminal splits, diff views, Lazygit) cleanly clean up after themselves on `TermClose` via automated `bdelete!` and `tabclose` callbacks.
4. **Leader Key Consistency**: `<Space>` is globally designated as `<leader>`, providing ergonomic, non-conflicting keybindings.
