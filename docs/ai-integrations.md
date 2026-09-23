# AI Integrations

This configuration features modular integrations for modern coding assistants and local LLM completions located in [`lua/ai/`](file:///home/cloud/.config/nvim/lua/ai/).

---

## 1. Modular Aggregator (`lua/ai/init.lua`)

The entry module [`lua/ai/init.lua`](file:///home/cloud/.config/nvim/lua/ai/init.lua) collects plugin specifications from individual AI provider files and injects them directly into the root `lazy.nvim` setup call:

```lua
local antigravity = require("ai.antigravity")

local specs = {}
for _, spec in ipairs(antigravity.specs) do
  table.insert(specs, spec)
end

return specs
```

To enable alternative AI assistants (Claude Code, Copilot, Ollama), uncomment their corresponding require statements and iteration loops in this file.

---

## 2. Google Antigravity CLI Integration (`lua/ai/antigravity.lua`)

The Antigravity integration ([`lua/ai/antigravity.lua`](file:///home/cloud/.config/nvim/lua/ai/antigravity.lua)) embeds the autonomous agent CLI (`agy`) directly into an interactive Neovim side-panel.

### Keymaps & Features
| Keymap | Mode | Description |
| :--- | :---: | :--- |
| `<leader>ai` | Normal | **Toggle Antigravity Panel**: Opens a vertical split terminal running `agy` at 25% window width. Pressing it again toggles the window (hides/restores) while preserving the active agent job. |
| `<leader>ad` | Normal | **Toggle Diffview**: Seamlessly opens or closes `DiffviewOpen`/`DiffviewClose` to inspect changes proposed by the Antigravity agent. |
| `<leader>as` | Normal | **Resize Small (25%)**: Shrinks the active Antigravity panel to 25% screen width. |
| `<leader>am` | Normal | **Resize Medium (42%)**: Expands the active Antigravity panel to 42% screen width. |
| `<leader>al` | Normal | **Resize Large (65%)**: Expands the active Antigravity panel to 65% screen width for extensive plan and log reviews. |

*(Note: The `<leader>as`, `<leader>am`, and `<leader>al` shortcuts are buffer-local to the Antigravity terminal buffer to avoid conflicting with other window operations.)*

---

## 3. Claude Code Integration (`lua/ai/claudecode.lua`)

Configured in [`lua/ai/claudecode.lua`](file:///home/cloud/.config/nvim/lua/ai/claudecode.lua), this module provides a vertical split panel for Anthropic's Claude Code terminal interface (`claude`).

### Keymaps
| Keymap | Mode | Description |
| :--- | :---: | :--- |
| `<leader>ci` | Normal | **Toggle Claude Code Panel**: Spawns or toggles a vertical split terminal executing `claude`. |
| `<leader>cs` | Normal / Term | **Resize Small (25%)**: Sets Claude Code panel width to 25%. |
| `<leader>ce` | Normal / Term | **Resize Medium (65%)**: Sets Claude Code panel width to 65%. |
| `<leader>ct` | Normal / Term | **Resize Full (100%)**: Expands the panel across the entire editor width. |

---

## 4. GitHub Copilot & Privacy Guard (`lua/ai/copilot.lua`)

The GitHub Copilot integration ([`lua/ai/copilot.lua`](file:///home/cloud/.config/nvim/lua/ai/copilot.lua)) pairs [copilot.lua](https://github.com/zbirenbaum/copilot.lua) with [CopilotChat.nvim](https://github.com/CopilotC-Nvim/CopilotChat.nvim).

### Privacy Protection Gatekeeper
To prevent intellectual property or proprietary company code from leaking into external cloud models, Copilot is **lazy-loaded** and protected behind an explicit user command:

```vim
:CopilotStart
```

When `:CopilotStart` is executed:
1. It validates the current working directory against a whitelist (`~/projects`, `~/workspace`).
2. If the current directory is not within a safe path, initialization is immediately blocked with a warning notification:
   `Privacy Protection: Copilot blocked in this directory!`
3. If safe, `copilot.lua` and `CopilotChat` are loaded dynamically and keymaps are bound.

### Copilot Keymaps (Post-Activation)
| Shortcut | Mode | Description |
| :--- | :---: | :--- |
| `<leader>cc` | Normal / Visual | Toggle CopilotChat vertical panel. |
| `<leader>cr` | Normal | Clear CopilotChat conversation history. |
| `<C-e>` | Insert | Smart accept inline ghost text suggestion (falls back to native `<C-e>` if none). |
| `<M-.>` | Insert | Cycle to next inline completion suggestion. |
| `<M-]>` / `<M-[>` | Insert | Cycle next/previous inline suggestion. |
| `<M-x>` | Insert | Dismiss current inline suggestion. |

---

## 5. Local LLM Autocompletion & Ollama (`lua/ai/ollama.lua`)

Local, fully offline code completions are powered by [minuet-ai.nvim](https://github.com/milanglacier/minuet-ai.nvim) connecting to an Ollama server running locally at `http://127.0.0.1:11434`.

### Keymaps & Features
| Keymap | Mode | Description |
| :--- | :---: | :--- |
| `<C-y>` | Insert | **Trigger Autocomplete**: Manually queries the local model (`qwen2.5-coder:7b`) for code completion at the cursor. |
| `<leader>os` | Normal | **Switch Model**: Dynamically toggles between `qwen2.5-coder:1.5b` (ultra-fast) and `qwen2.5-coder:7b` (high-accuracy) with instant feedback notifications. |
