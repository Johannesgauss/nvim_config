# Core Configuration

The core configuration modules establish foundational editor settings, terminal behaviors, buffer management, and primary navigation keymaps.

---

## 1. Editor Options (`lua/core/options.lua`)

The options in [`lua/core/options.lua`](file:///home/cloud/.config/nvim/lua/core/options.lua) define general behavior across the editor:

```lua
local opt = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = " "

opt.splitright = true
opt.laststatus = 2
opt.number = true
opt.relativenumber = true
opt.clipboard = "unnamedplus"
opt.smartindent = true
opt.tabstop = 8
opt.shiftwidth = 8
opt.expandtab = false
```

### Option Breakdown
| Setting | Value | Rationale / Behavior |
| :--- | :--- | :--- |
| `mapleader` / `maplocalleader` | `" "` (Space) | Sets the global leader key to Spacebar for ergonomic key chord expansion. |
| `splitright` | `true` | Vertical splits automatically open to the right of the active window. |
| `laststatus` | `2` | Always display the statusline, even when only a single window is open. |
| `number` | `true` | Displays line numbers in the gutter. |
| `relativenumber` | `true` | Displays relative line numbers above and below cursor for instant vertical motions (`5k`, `12j`). |
| `clipboard` | `"unnamedplus"` | Synchronizes the default `""` register with the system clipboard (Wayland/X11/wl-copy/xclip). |
| `smartindent` | `true` | Enables smart auto-indentation when starting new lines based on syntax syntax blocks. |
| `tabstop` | `8` | Renders a tab character (`\t`) as 8 columns wide. |
| `shiftwidth` | `8` | Number of columns used for auto-indenting and indentation shift commands (`>>`, `<<`). |
| `expandtab` | `false` | Inserts real tab characters (`\t`) when pressing `<Tab>`, retaining classic Vim tab behavior. |

---

## 2. Terminal Automation & Filetypes

[`lua/core/options.lua`](file:///home/cloud/.config/nvim/lua/core/options.lua#L16-L38) defines autocmds for terminal buffers and custom filetypes:

### Auto-Insert Mode
Automatically enters terminal insert mode upon entering any terminal buffer (`term://*`):
```lua
vim.api.nvim_create_autocmd({"WinEnter", "BufWinEnter", "TermOpen"}, {
    pattern = "term://*",
    callback = function() vim.cmd("startinsert") end,
})
```

### Clean Terminal Gutters
Disables line numbers and relative numbers within terminal buffers:
```lua
vim.api.nvim_create_autocmd("TermOpen", {
    callback = function()
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
    end,
})
```

### Auto-Delete Terminals on Exit
Ensures closed terminal sessions do not linger in the buffer list:
```lua
vim.api.nvim_create_autocmd("TermClose", {
    callback = function()
        vim.cmd("bdelete!")
    end,
})
```

### Custom Filetype Registration
Explicitly registers `.prisma` files with the `prisma` filetype for tree-sitter highlighting:
```lua
vim.filetype.add({
  extension = {
    prisma = "prisma",
  },
})
```

---

## 3. Global Navigation & Terminal Keymaps (`lua/core/keymaps.lua`)

Located at [`lua/core/keymaps.lua`](file:///home/cloud/.config/nvim/lua/core/keymaps.lua), these keymaps provide seamless navigation and quick-terminal toggling.

### Quick Escape (`jk`)
- **Insert Mode**: Typing `jk` sends `<Esc>`, allowing fast exit from insert mode without reaching for the escape key.
- **Terminal Mode**: In terminal buffers, `jk` triggers `<C-\><C-n>` to switch the terminal to Normal mode, allowing scrollback navigation.

### Split Navigation
- Normal mode `<C-h>` moves left (`<C-w>h`).
- Normal mode `<C-l>` moves right (`<C-w>l`).
- Terminal mode `<C-h>`, `<C-l>`, and `<C-k>` allow jumping directly out of the terminal into adjacent editor windows without leaving terminal mode first.

### Integrated Bottom Terminal (`<C-j>`)
Pressing `<C-j>` in Normal or Terminal mode toggles an integrated persistent terminal at the bottom of the screen:
- Occupies 20% of the editor height (`belowright split`).
- Detects the active non-tree main window via `get_main_win()` so NvimTree is never split incorrectly.
- Fixes the window height (`winfixheight = true`).
- Preserves terminal session buffer (`term_buf`) across toggles.

### Full-Screen Lazygit Tab (`<leader>gg`)
Pressing `<leader>gg` launches an isolated, dedicated full-screen Git management view:
- Opens a clean new tabpage (`:tabnew`).
- Launches `lazygit` inside the terminal.
- Disables line numbers.
- Registers an ephemeral `TermClose` autocmd that immediately closes the tab (`:tabclose`) when exiting Lazygit, returning cleanly to the exact previous workspace state.

### File Tree Toggle (`<leader>n`)
- Triggers `:NvimTreeToggle<CR>` to open or hide the file tree explorer.
