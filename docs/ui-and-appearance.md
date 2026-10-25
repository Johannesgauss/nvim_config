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

Neovim defaults to modern graphical aesthetics (24-bit truecolor, floating diagnostic text, rounded borders, sign columns). The module [`lua/ui/vim_look.lua`](file:///home/cloud/.config/nvim/lua/ui/vim_look.lua) introduces dedicated commands to toggle and persist an authentic, retro terminal Vim look as well as a full ASCII TTY-compatible mode:

```vim
:ToggleVimLook
:ToggleTTY
```

### Comparison Matrix

| Property | Modern Neovim (Default) | Classic Vim Look (`:ToggleVimLook`) | TTY Mode (`:ToggleTTY`) |
| :--- | :--- | :--- | :--- |
| **Color Depth** | 24-bit RGB Truecolor (`termguicolors = true`) | 16/256 ANSI terminal colors (`termguicolors = false`) | 16-color VGA/ANSI (`termguicolors = false`) |
| **Colorscheme** | `catppuccin-mocha` | `vim` (classic Vim default palette) | `vim` with 16-color contrast overrides |
| **Statusline** | Custom Lua renderer with Nerd Font icons | Inverted ASCII text statusline (`%<%f %h%m%r%=%-14.(%l,%c%V%) %P`) | Inverted ASCII text statusline |
| **Mode Display** | Hidden from command line (`showmode = false`) | Visible bold text at bottom left (`-- INSERT --`, `-- VISUAL --`) | Visible bold text at bottom left |
| **Ruler** | Disabled / in custom statusline | Enabled (`ruler = true`) | Enabled (`ruler = true`) |
| **Line Numbers** | Hybrid (`number = true`, `relativenumber = true`) | Hybrid (`number = true`, `relativenumber = true`) | Hybrid (`number = true`, `relativenumber = true`) |
| **Sign Column** | `signcolumn = "auto"` | `signcolumn = "auto"` (expands only when diagnostics exist) | `signcolumn = "auto"` |
| **Cursor Line** | Optional horizontal highlight | `cursorline = false` | `cursorline = false` |
| **Empty Lines** | Hidden / subtle | Classic Blue `~` tildes (`fillchars = { eob = "~" }`) | Classic Blue `~` tildes |
| **Separators / Folds** | UTF-8 (`│`, `─`) | Classic vertical bar `\|` | Pure ASCII (`\|`, `-`) |
| **Diagnostics** | UTF-8 symbols (`✘`, `▲`, `⚑`, `»`, `●`) | UTF-8 symbols (`✘`, `▲`, `⚑`, `»`, `●`) | Pure ASCII (`E`, `W`, `H`, `I`, `*`) |
| **Floats & Popups** | Rounded UTF-8 (`╭─╮`) | Rounded UTF-8 (`╭─╮`) | Pure ASCII (`+`, `-`, `\|`) |
| **Tree Explorer** | Devicons & Unicode folder glyphs | Devicons & Unicode folder glyphs | NERDTree-style ASCII glyphs (`[D]`, `[O]`, `[E]`, `*`) |
| **Telescope** | Devicons & Unicode borders | Devicons & Unicode borders | Pure ASCII borders, devicons disabled |
| **Clipboard** | System clipboard (`unnamedplus`) | System clipboard (`unnamedplus`) | Clean fallback (disabled if no GUI display) |

---

## 4. TTY Console Mode (`:ToggleTTY`)

When working inside a Linux virtual console (e.g. `/dev/tty3` reached via `Ctrl+Alt+F3`) or a raw serial terminal, Unicode fonts and 24-bit color palettes are unavailable. Modern symbols frequently render as broken glyphs, question marks, or box artifacts.

The `:ToggleTTY` command solves this by enabling a retro Vim style engineered specifically for standard 16-color virtual consoles:

```vim
:ToggleTTY
```

### Key TTY Adaptations
1. **Classic Vim Aesthetic**: Instantly disables `termguicolors`, switches to `colorscheme vim`, and replaces the statusline with the classic inverted text ruler.
2. **Pure ASCII Borders & Separators**: Wraps floating window generators (`vim.lsp.util.open_floating_preview`, `vim.diagnostic.open_float`, `cmp`, and `telescope`) with ASCII borders (`+`, `-`, `|`).
3. **Pure ASCII Diagnostic Indicators**: Replaces Unicode diagnostic symbols with high-visibility ASCII single-letter signs (`E` for error, `W` for warning, `H` for hint, `I` for info) and `*` virtual text.
4. **NERDTree ASCII Glyphs for Nvim-Tree**: Reconfigures `nvim-tree` dynamically to replace all file/folder devicons with classic ASCII tags (`[D]` for directory, `[O]` for open directory, `[E]` for empty directory, `*` for files).
5. **Headless Clipboard Protection**: In pure TTY environments where neither `$DISPLAY` nor `$WAYLAND_DISPLAY` is active, `:ToggleTTY` safely sets `clipboard = ""` to eliminate terminal freeze/hangs caused by external clipboard providers.
6. **Universal Cross-Platform Auto-Detection**:
   - Works automatically on any machine, Linux distribution, or Unix system without requiring manual toggles or copied state files.
   - Detects real TTY consoles via `$TERM` (`linux`, `fbcon`, `console`, `vt100`, etc.) and the active console terminal device (`/dev/tty1`..`/dev/tty63`, `/dev/console`, `/dev/ttyS*`, `/dev/ttyv*`).
   - When opened in a virtual console (e.g. `Ctrl+Alt+F3`), Neovim automatically boots into TTY + Classic Vim mode.
   - When opened in a graphical terminal emulator (e.g. Alacritty, Kitty, WezTerm, GNOME Terminal), Neovim automatically boots into the Modern UI.
   - Running `:ToggleTTY` provides manual override capability whenever needed.

---

## 5. Markdown Viewing & Reader Mode (`lua/ui/markdown_view.lua`)

For reading documentation, technical specifications, or notes directly inside Neovim without visual clutter, the configuration provides a dedicated distraction-free **Reader Mode**:

```vim
:ToggleMarkdownView
```

### Shortcuts
- `<leader>mv`: Toggles **Reader Mode** on the active Markdown buffer.
- `q`: While in Reader Mode, pressing `q` in Normal mode immediately exits Reader Mode and returns to standard editing.
- `<leader>mr`: Toggles inline visual Markdown rendering (`render-markdown.nvim`).

### Reader Mode Behaviors
1. **Distraction-Free Layout**: Hides line numbers, relative numbers, sign columns, and fold columns.
2. **Reading Ergonomics**: Enables soft line wrapping (`wrap = true`), break indenting (`breakindent = true`), and breaks lines strictly between words (`linebreak = true`).
3. **Syntax Concealment**: Sets `conceallevel = 2` and `concealcursor = "nc"`, hiding raw Markdown tokens (`**`, `__`, `[]()`, backticks) and rendering styled text.
4. **Safety Against Accidental Edits**: Sets `modifiable = false` and `readonly = true` to protect the document while navigating or scrolling.
5. **Statusline Indicator**: Displays an active `[READ-MODE]` badge in the statusline so the reader's state is immediately apparent.
6. **Restoration**: Disabling Reader Mode restores the exact previous window and buffer options.
