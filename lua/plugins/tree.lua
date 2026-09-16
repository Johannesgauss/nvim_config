-- ~/.config/nvim/lua/plugins/tree.lua
return {
  "nvim-tree/nvim-tree.lua",
  version = "*",
  lazy = false, 
  dependencies = {
    "nvim-tree/nvim-web-devicons", 
  },
  config = function()
    local function my_on_attach(bufnr)
      local api = require("nvim-tree.api")

      local function opts(desc)
        return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
      end

      -- First, load default mappings
      api.config.mappings.default_on_attach(bufnr)

      -- NERDTree mappings mapping to NvimTree API
      -- o: Open file or toggle folder
      vim.keymap.set("n", "o", api.node.open.edit, opts("Open"))
      
      -- go: Open file but keep focus on tree
      vim.keymap.set("n", "go", function()
        local node = api.tree.get_node_under_cursor()
        if node then
          api.node.open.edit(node)
          api.tree.focus()
        end
      end, opts("Open: Silent"))

      -- t: Open file in new tab
      vim.keymap.set("n", "t", api.node.open.tab, opts("Open: New Tab"))

      -- T: Open file in new tab silently (keep focus in tree)
      vim.keymap.set("n", "T", function()
        local node = api.tree.get_node_under_cursor()
        if node then
          api.node.open.tab(node)
          api.tree.focus()
        end
      end, opts("Open: New Tab Silent"))

      -- i: Open split (horizontal split)
      vim.keymap.set("n", "i", api.node.open.horizontal, opts("Open: Horizontal Split"))

      -- gi: Open split silently (keep focus in tree)
      vim.keymap.set("n", "gi", function()
        local node = api.tree.get_node_under_cursor()
        if node then
          api.node.open.horizontal(node)
          api.tree.focus()
        end
      end, opts("Open: Horizontal Split Silent"))

      -- s: Open vertical split
      vim.keymap.set("n", "s", api.node.open.vertical, opts("Open: Vertical Split"))

      -- gs: Open vertical split silently (keep focus in tree)
      vim.keymap.set("n", "gs", function()
        local node = api.tree.get_node_under_cursor()
        if node then
          api.node.open.vertical(node)
          api.tree.focus()
        end
      end, opts("Open: Vertical Split Silent"))

      -- p: Go to parent directory
      vim.keymap.set("n", "p", api.node.navigate.parent, opts("Parent Directory"))

      -- P: Go to root node / close directory
      vim.keymap.set("n", "P", api.node.navigate.parent_close, opts("Close Directory"))

      -- C: Change tree root to the selected directory (CD)
      vim.keymap.set("n", "C", api.tree.change_root_to_node, opts("CD"))

      -- u: Move tree root up one directory (Up)
      vim.keymap.set("n", "u", api.tree.change_root_to_parent, opts("Up"))

      -- r: Refresh current directory
      vim.keymap.set("n", "r", api.tree.reload, opts("Refresh"))

      -- R: Refresh root directory
      vim.keymap.set("n", "R", api.tree.reload, opts("Refresh"))

      -- I: Toggle hidden files (show/hide dotfiles)
      vim.keymap.set("n", "I", api.filter.dotfiles.toggle, opts("Toggle Filter: Dotfiles"))

      -- cd: Change Vim CWD to selected directory
      vim.keymap.set("n", "cd", api.tree.change_root_to_node, opts("CD"))

      -- ?: Toggle help menu
      vim.keymap.set("n", "?", api.tree.toggle_help, opts("Help"))
    end

    require("nvim-tree").setup({
      on_attach = my_on_attach,
      sync_root_with_cwd = true,
      respect_buf_cwd = true,
      update_focused_file = {
        enable = true,
        update_root = true,
      },
      sort = {
        sorter = "case_sensitive",
      },
      view = {
        width = 30,             
        side = "left",          
        number = true,         -- CRITICAL FIX: Enables absolute line numbers (set number)
        relativenumber = true, -- CRITICAL FIX: Enables relative vertical jump numbers (set relativenumber)
      },
      renderer = {
        group_empty = true,     
      },
      git = {
        enable = true,          
        ignore = true,          
        timeout = 500,
      },
      filters = {
        dotfiles = false,       
        git_ignored = true,     
        custom = {              
          "^\\.git$",          
        },
      },
    })
  end,
}
