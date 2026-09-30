return {
  -- Mason for managing LSP servers, linters, formatters
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
          }
        }
      })
    end
  },

  -- mason-lspconfig bridges mason and lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
        require("mason-lspconfig").setup({
            ensure_installed = { "ts_ls", "clangd", "lua_ls", "pyright" },
            -- handlers = { -- Configuração padrão para todos os servidores instalados pelo Mason function(server_name) require("lspconfig")[server_name].setup({}) end, },
        })
     end,
  },
  -- LSPConfig for configuring the LSP servers
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local cmp_nvim_lsp = require("cmp_nvim_lsp")

      -- Advertise nvim-cmp capabilities to LSP servers
      local capabilities = cmp_nvim_lsp.default_capabilities()

      -- Stabilize floating preview for signature help so it never flickers or oscillates while typing
      local util = require("vim.lsp.util")
      local orig_open_floating_preview = util.open_floating_preview
      util.open_floating_preview = function(contents, syntax, opts)
        opts = opts or {}
        if opts.focus_id == "textDocument/signatureHelp" then
          opts.close_events = { "InsertLeave", "BufLeave" }
          opts.anchor_bias = opts.anchor_bias or "above"
          local cur_buf = vim.api.nvim_get_current_buf()
          local existing_win = vim.b[cur_buf].lsp_floating_preview
          if existing_win and vim.api.nvim_win_is_valid(existing_win) then
            local ok, is_sig = pcall(vim.api.nvim_win_get_var, existing_win, "textDocument/signatureHelp")
            if ok and is_sig then
              opts._update_win = existing_win
              local width, height = util._make_floating_popup_size(contents, opts)
              pcall(vim.api.nvim_win_set_config, existing_win, {
                width = width,
                height = height,
              })
            end
          end
        end
        return orig_open_floating_preview(contents, syntax, opts)
      end

      -- Keymaps on LspAttach
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", {}),
        callback = function(ev)
          local bufnr = ev.buf
          
          local class_inspector = require("core.class_inspector")

          local function show_docs()
            local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" })
            if #clients == 0 then
              local cword = vim.fn.expand("<cword>")
              if cword and cword ~= "" then
                local ok = pcall(vim.cmd.help, cword)
                if not ok then
                  vim.cmd("normal! K")
                end
              end
              return
            end

            local cur_word = vim.fn.expand("<cword>")
            local client = clients[1]
            local h_params = vim.lsp.util.make_position_params(0, client.offset_encoding)

            client:request("textDocument/hover", h_params, function(h_err, h_result)
              local lines = {}
              if not h_err and h_result and h_result.contents then
                lines = vim.lsp.util.convert_input_to_markdown_lines(h_result.contents)
              end

              class_inspector.resolve_class_details(bufnr, client, h_params, cur_word, lines, function(class_lines)
                if class_lines and #class_lines > 0 then
                  if #lines > 0 then
                    table.insert(lines, "")
                    table.insert(lines, "---")
                  end
                  for _, cl in ipairs(class_lines) do
                    table.insert(lines, cl)
                  end
                end

                if #lines > 0 then
                  util.open_floating_preview(lines, "markdown", {
                    border = "rounded",
                    focus_id = "textDocument/hover",
                  })
                else
                  vim.notify("No information available", vim.log.levels.INFO)
                end
              end)
            end)
          end

          -- Set keymaps
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition", buffer = bufnr })
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration", buffer = bufnr })
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation", buffer = bufnr })
          vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "Go to references", buffer = bufnr })
          vim.keymap.set("n", "K", show_docs, { desc = "Hover docs / Class details", buffer = bufnr })
          vim.keymap.set("n", "<C-k>", show_docs, { desc = "Hover docs / Class details", buffer = bufnr })
          vim.keymap.set("n", "<leader>cs", function() class_inspector.inspect_class(bufnr) end, { desc = "Inspect Class/Struct components & methods", buffer = bufnr })
          vim.keymap.set("n", "<leader>co", vim.lsp.buf.document_symbol, { desc = "Class & Symbol Outline", buffer = bufnr })
          vim.keymap.set("n", "gO", vim.lsp.buf.document_symbol, { desc = "Class & Symbol Outline", buffer = bufnr })
          vim.keymap.set({ "n", "i" }, "<C-s>", function()
            vim.lsp.buf.signature_help({
              close_events = { "InsertLeave", "BufLeave" },
              anchor_bias = "above",
            })
          end, { desc = "Signature help (function args)", buffer = bufnr })
          vim.keymap.set("n", "<leader>k", function()
            vim.lsp.buf.signature_help({
              close_events = { "InsertLeave", "BufLeave" },
              anchor_bias = "above",
            })
          end, { desc = "Signature help (function args)", buffer = bufnr })
          vim.keymap.set("n", "<leader>th", function()
            local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
            vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
          end, { desc = "Toggle Inlay Hints", buffer = bufnr })
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol", buffer = bufnr })
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code actions", buffer = bufnr })
          vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic", buffer = bufnr })
          vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic", buffer = bufnr })
          vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Open diagnostic float", buffer = bufnr })
          vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Add diagnostics to loclist", buffer = bufnr })

          -- Enable inlay hints if supported by the client
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client:supports_method("textDocument/inlayHint", { bufnr = bufnr }) then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
          end

          local function trigger_signature_help()
            local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/signatureHelp" })
            if #clients == 0 or vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i" then
              return
            end

            local c = clients[1]
            local params = vim.lsp.util.make_position_params(0, c.offset_encoding)
            vim.lsp.buf_request(bufnr, "textDocument/signatureHelp", params, function(err, result)
              if err or not result or not result.signatures or #result.signatures == 0 then
                -- Closed or outside function call: dismiss the floating window cleanly
                local existing = vim.b[bufnr].lsp_floating_preview
                if existing and vim.api.nvim_win_is_valid(existing) then
                  local ok, is_sig = pcall(vim.api.nvim_win_get_var, existing, "textDocument/signatureHelp")
                  if ok and is_sig then
                    pcall(vim.api.nvim_win_close, existing, true)
                  end
                end
                return
              end

              -- Display or update the signature window smoothly
              if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
                vim.lsp.buf.signature_help({
                  focusable = false,
                  silent = true,
                  close_events = { "InsertLeave", "BufLeave" },
                  anchor_bias = "above",
                })
              end
            end)
          end

          -- Auto signature help when typing arguments in insert mode (smooth, non-oscillating)
          local sig_timer = nil
          vim.api.nvim_create_autocmd({ "TextChangedI", "CursorHoldI" }, {
            group = vim.api.nvim_create_augroup("LspAutoSig_" .. bufnr, { clear = true }),
            buffer = bufnr,
            callback = function()
              local col = vim.api.nvim_win_get_cursor(0)[2]
              local line = vim.api.nvim_get_current_line()
              local char = line:sub(col, col)

              -- Fast trigger on opening parenthesis or comma
              if char == "(" or char == "," then
                trigger_signature_help()
                return
              end

              -- Debounced update while typing parameters
              if sig_timer then
                sig_timer:stop()
              end
              sig_timer = vim.defer_fn(function()
                trigger_signature_help()
              end, 200)
            end,
          })
        end,
      })

      -- Set default capabilities globally for all servers
      vim.lsp.config("*", {
        capabilities = capabilities,
      })

      -- Configure clangd (C/C++) with argument placeholders
      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--completion-style=detailed",
          "--function-arg-placeholders=1",
        },
      })

      -- Configure pyright (Python)
      vim.lsp.config("pyright", {
        settings = {
          python = {
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "workspace",
            }
          }
        }
      })

      -- Configure ts_ls (JavaScript/TypeScript)
      vim.lsp.config("ts_ls", {})

      -- Configure lua_ls (Lua)
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
            },
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = {
              enable = false,
            },
          },
        },
      })

      -- Enable servers
      vim.lsp.enable({ "clangd", "pyright", "ts_ls", "lua_ls" })

      -- Configure diagnostic icons/signs
      local signs = { Error = "✘", Warn = "▲", Hint = "⚑", Info = "»" }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
      end

      -- Configure diagnostic display behavior
      vim.diagnostic.config({
        virtual_text = {
          prefix = "●",
        },
        update_in_insert = false,
        underline = true,
        severity_sort = true,
        float = {
          border = "rounded",
          source = "always",
        },
      })
    end
  },

  -- Autocompletion engine and sources
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-k>"] = cmp.mapping.select_prev_item(), -- previous suggestion
          ["<C-j>"] = cmp.mapping.select_next_item(), -- next suggestion
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(), -- show completion suggestions
          ["<C-e>"] = cmp.mapping.abort(), -- close completion window
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        -- sources for autocompletion
        sources = cmp.config.sources({
          { name = "nvim_lsp" }, -- lsp
          { name = "luasnip" }, -- snippets
          { name = "buffer" }, -- text within current buffer
          { name = "path" }, -- file system paths
        }),
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })
    end
  }
}
