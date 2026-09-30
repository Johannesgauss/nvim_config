local function setup_treesitter_compat()
  -- Neovim 0.11/0.12 compatibility shim:
  -- In Neovim 0.11+, query matches pass captures as tables of nodes (TSNode[]),
  -- and removed support for opts.all = false. nvim-treesitter master branch predicates/directives
  -- expect match[id] to be a single TSNode. Wrap match access and get_node_text/get_range
  -- to prevent "attempt to call method 'range' (a nil value)".

  if vim.treesitter.query then
    local orig_add_directive = vim.treesitter.query.add_directive
    vim.treesitter.query.add_directive = function(name, handler, opts)
      local wrapped_handler = handler
      if opts and opts.all == false then
        wrapped_handler = function(match, pattern, bufnr, pred, metadata)
          local proxy_match = setmetatable({}, {
            __index = function(_, k)
              local v = match[k]
              if type(v) == "table" and not getmetatable(v) then
                return v[1]
              end
              return v
            end,
            __newindex = match,
          })
          return handler(proxy_match, pattern, bufnr, pred, metadata)
        end
      end
      return orig_add_directive(name, wrapped_handler, opts)
    end

    local orig_add_predicate = vim.treesitter.query.add_predicate
    vim.treesitter.query.add_predicate = function(name, handler, opts)
      local wrapped_handler = handler
      if opts and opts.all == false then
        wrapped_handler = function(match, pattern, bufnr, pred, metadata)
          local proxy_match = setmetatable({}, {
            __index = function(_, k)
              local v = match[k]
              if type(v) == "table" and not getmetatable(v) then
                return v[1]
              end
              return v
            end,
            __newindex = match,
          })
          return handler(proxy_match, pattern, bufnr, pred, metadata)
        end
      end
      return orig_add_predicate(name, wrapped_handler, opts)
    end
  end

  if vim.treesitter.get_node_text then
    local orig_get_node_text = vim.treesitter.get_node_text
    vim.treesitter.get_node_text = function(node, source, opts)
      if type(node) == "table" and not getmetatable(node) then
        node = node[1]
      end
      if not node then
        return ""
      end
      return orig_get_node_text(node, source, opts)
    end
  end

  if vim.treesitter.get_range then
    local orig_get_range = vim.treesitter.get_range
    vim.treesitter.get_range = function(node, source, metadata)
      if type(node) == "table" and not getmetatable(node) then
        node = node[1]
      end
      if not node then
        return { 0, 0, 0, 0, 0, 0 }
      end
      return orig_get_range(node, source, metadata)
    end
  end
end

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
  build = ":TSUpdate",
  init = function()
    setup_treesitter_compat()
  end,
  config = function()
    setup_treesitter_compat()
    if package.loaded["nvim-treesitter.query_predicates"] then
      package.loaded["nvim-treesitter.query_predicates"] = nil
      require("nvim-treesitter.query_predicates")
    end
    require("nvim-treesitter.configs").setup({
      ensure_installed = { "prisma", "lua", "vim", "vimdoc", "markdown", "markdown_inline" },
      highlight = {
        enable = true,
      },
    })
  end,
}
