-- ~/.config/nvim/lua/plugins/tree.lua
return {
  "nvim-tree/nvim-tree.lua",
  version = "*",
  lazy = false, 
  dependencies = {
    "nvim-tree/nvim-web-devicons", 
  },
  config = function()
    require("nvim-tree").setup({
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
