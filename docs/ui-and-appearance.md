# UI & Appearance

This document details the visual components of the configuration, including theme setup, the dynamic custom statusline, and the persistent classic Vim look toggle engine.

---

## 1. Theme Configuration (`lua/plugins/theme.lua`)

The editor's default modern theme is [Catppuccin Mocha](https://github.com/catppuccin/nvim), configured in [`lua/plugins/theme.lua`](file:///home/cloud/.config/nvim/lua/plugins/theme.lua):

```lua
return {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
        transparent_background = true,
    },
    config = function(_, opts)
        require("catppuccin").setup(opts)
        vim.cmd.colorscheme("catppuccin-mocha")
    end,
}
```

### Key Properties
- **Priority `1000`**: Guarantees the theme loads before all other plugins during the `lazy.nvim` startup cycle to prevent color flashing or un-styled UI elements.
- **`transparent_background = true`**: Allows your terminal emulator's native background or blur/transparency effects to show through behind editor buffers.

---

## 2. Dynamic Statusline (`lua/ui/statusline.lua`)

A lightweight, high-performance statusline written in pure Lua in [`lua/ui/statusline.lua`](file:///home/cloud/.config/nvim/lua/ui/statusline.lua). It dynamically adapts based on whether the current workspace is a Git repository:

```lua
vim.opt.statusline = "%!v:lua.Render_Statusline()"
```

### Components
```
[ Workspace / Git Branch ]  [ File Path & Modified ]      [ Cursor & Progress ]
  󰉖 nvim_config  branch:main │   lua/init.lua [+]     %=    12:8 │ 45%
```

1. **Workspace & Git Detection (`get_workspace_status`)**:
   - Queries `git rev-parse --is-inside-work-tree` and `git branch --show-current`.
   - **Git Workspace**: Displays `󰉖 <repo_name>  branch:<branch_name> │`.
   - **Standard Workspace**: Falls back to `󰉖 <current_directory_name>`.
2. **File State**:
   - `%f`: Relative file path.
   - `%m`: Modified flag indicator (`[+]` if unsaved changes).
3. **Alignment**:
   - `%=`: Separation point pushing subsequent indicators to the right edge.
4. **Metrics**:
   - `%l:%c`: Line number and column coordinate.
   - `%p%%`: Percentage position within the file.

---

## 3. Persistent Classic Vim Look Engine (`lua/ui/vim_look.lua`)

Neovim defaults to modern graphical aesthetics (24-bit truecolor, floating diagnostic text, rounded borders, sign columns). The module [`lua/ui/vim_look.lua`](file:///home/cloud/.config/nvim/lua/ui/vim_look.lua) introduces a dedicated command to toggle and persist an authentic, retro terminal Vim look:

```vim
:ToggleVimLook
```

### Comparison Matrix

| Property | Modern Neovim (Default) | Classic Vim Look (`:ToggleVimLook`) |
| :--- | :--- | :--- |
| **Color Depth** | 24-bit RGB Truecolor (`termguicolors = true`) | 16/256 ANSI terminal colors (`termguicolors = false`) |
| **Colorscheme** | `catppuccin-mocha` | `vim` (classic Vim default palette) |
| **Statusline** | Custom Lua renderer with Nerd Font icons | Inverted ASCII text statusline (`%<%f %h%m%r%=%-14.(%l,%c%V%) %P`) |
| **Mode Display** | Hidden from command line (`showmode = false`) | Visible bold text at bottom left (`-- INSERT --`, `-- VISUAL --`) |
| **Ruler** | Disabled / in custom statusline | Enabled (`ruler = true`) |
| **Line Numbers** | Hybrid (`number = true`, `relativenumber = true`) | Hybrid (`number = true`, `relativenumber = true`) |
| **Sign Column** | `signcolumn = "auto"` (gutter padding) | `signcolumn = "no"` (code hugs left border) |
| **Cursor Line** | Optional horizontal highlight | `cursorline = false` |
| **Empty Lines** | Hidden / subtle | Classic Blue `~` tildes (`fillchars = { eob = "~" }`) |
| **Diagnostics** | Virtual text inline (`● Error: ...`) & signs | Suppressed virtual text & signs for distraction-free editing |

### Persistence Mechanism
- State is written to **`~/.local/state/nvim/vim_look_enabled`** (`vim.fn.stdpath("state")`).
- On editor startup:
  1. The module captures current modern state defaults.
  2. If the persisted file contains `true`, the classic Vim look is applied quietly.
  3. A `VimEnter` autocmd re-ensures the classic look after any lazy-loaded plugins finish their setup.
- When toggling via `:ToggleVimLook`, the preference is immediately saved to disk, so your visual choice persists across restarts without requiring any configuration edits.
