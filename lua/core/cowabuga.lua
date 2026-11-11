local M = {}

-- In-memory registry of project roots to unity include files
local active_targets = {}

-- State persistence file path (~/.local/state/nvim/cowabuga_targets.json)
local function get_state_path()
    return vim.fs.joinpath(vim.fn.stdpath("state"), "cowabuga_targets.json")
end

-- Get global user clangd config file (~/.config/clangd/config.yaml) outside the repository
local function get_user_clangd_config_path()
    local xdg_config = vim.env.XDG_CONFIG_HOME
    local base = (xdg_config and xdg_config ~= "") and xdg_config or vim.fs.joinpath(vim.env.HOME, ".config")
    return vim.fs.joinpath(base, "clangd", "config.yaml")
end

-- Load persisted targets from disk
local function load_persisted_targets()
    local path = get_state_path()
    if vim.fn.filereadable(path) ~= 1 then
        return {}
    end
    local ok, content = pcall(vim.fn.readfile, path)
    if not ok or not content or #content == 0 then
        return {}
    end
    local text = table.concat(content, "\n")
    local ok_json, data = pcall(vim.json.decode, text)
    if ok_json and type(data) == "table" then
        return data
    end
    return {}
end

-- Save targets to disk
local function save_persisted_targets(targets)
    local path = get_state_path()
    local dir = vim.fs.dirname(path)
    if vim.fn.isdirectory(dir) ~= 1 then
        pcall(vim.fn.mkdir, dir, "p")
    end
    local ok_json, json_text = pcall(vim.json.encode, targets)
    if ok_json and json_text then
        pcall(vim.fn.writefile, { json_text }, path)
    end
end

-- Update ~/.config/clangd/config.yaml outside the repo
local function update_user_clangd_config(project_root, unity_file)
    local config_path = get_user_clangd_config_path()
    local config_dir = vim.fs.dirname(config_path)
    if vim.fn.isdirectory(config_dir) ~= 1 then
        pcall(vim.fn.mkdir, config_dir, "p")
    end

    local lines = {}
    if vim.fn.filereadable(config_path) == 1 then
        lines = vim.fn.readfile(config_path)
    end

    -- Filter out any existing Cowabuga block for this project_root
    local new_lines = {}
    local skipping = false
    local start_marker = "# Cowabuga-Section-Start: " .. project_root
    local end_marker = "# Cowabuga-Section-End: " .. project_root

    for _, line in ipairs(lines) do
        if line == start_marker then
            skipping = true
        elseif line == end_marker then
            skipping = false
        elseif not skipping then
            table.insert(new_lines, line)
        end
    end

    -- Append the new section for this project
    local unity_dir = vim.fs.dirname(unity_file)
    table.insert(new_lines, start_marker)
    table.insert(new_lines, "---")
    table.insert(new_lines, "If:")
    table.insert(new_lines, "  PathMatch: " .. project_root .. "/.*")
    table.insert(new_lines, "CompileFlags:")
    table.insert(new_lines, "  Add:")
    table.insert(new_lines, "    - -ferror-limit=0")
    table.insert(new_lines, "    - -I" .. unity_dir)
    table.insert(new_lines, "    - -include")
    table.insert(new_lines, "    - " .. unity_file)
    table.insert(new_lines, end_marker)

    pcall(vim.fn.writefile, new_lines, config_path)
end

-- Remove Cowabuga entry from ~/.config/clangd/config.yaml outside the repo
local function remove_user_clangd_config(project_root)
    local config_path = get_user_clangd_config_path()
    if vim.fn.filereadable(config_path) ~= 1 then
        return
    end

    local lines = vim.fn.readfile(config_path)
    local new_lines = {}
    local skipping = false
    local start_marker = "# Cowabuga-Section-Start: " .. project_root
    local end_marker = "# Cowabuga-Section-End: " .. project_root

    for _, line in ipairs(lines) do
        if line == start_marker then
            skipping = true
        elseif line == end_marker then
            skipping = false
        elseif not skipping then
            table.insert(new_lines, line)
        end
    end

    pcall(vim.fn.writefile, new_lines, config_path)

    -- If a legacy .clangd was previously placed inside project_root by accident, remove it
    local repo_clangd = vim.fs.joinpath(project_root, ".clangd")
    if vim.fn.filereadable(repo_clangd) == 1 then
        local first_lines = vim.fn.readfile(repo_clangd, "", 3)
        for _, fl in ipairs(first_lines) do
            if fl:find("Cowabuga") then
                pcall(vim.fn.delete, repo_clangd)
                break
            end
        end
    end
end

--- Get root directory for a given buffer or file path
--- @param bufnr_or_path number|string|nil
--- @return string
function M.get_project_root(bufnr_or_path)
    local fname = ""
    if type(bufnr_or_path) == "number" then
        fname = vim.api.nvim_buf_get_name(bufnr_or_path)
    elseif type(bufnr_or_path) == "string" and bufnr_or_path ~= "" then
        fname = bufnr_or_path
    else
        fname = vim.api.nvim_buf_get_name(0)
    end

    if fname == "" then
        return vim.fs.normalize(vim.fn.getcwd())
    end

    local markers = {
        "compile_commands.json",
        "compile_flags.txt",
        ".clangd",
        ".clang-tidy",
        ".clang-format",
        "CMakeLists.txt",
        "Makefile",
        "meson.build",
        "configure.ac",
        ".git",
    }
    local root = vim.fs.root(fname, markers)
    if not root or root == vim.env.HOME then
        -- Check if file is within a "src" folder
        for dir in vim.fs.parents(fname) do
            if vim.fs.basename(dir) == "src" then
                root = vim.fs.dirname(dir)
                break
            end
        end
    end

    return vim.fs.normalize(root or vim.fn.getcwd())
end

--- Find candidate unity build files within a directory
--- @param root_dir string
--- @return string[]
function M.find_candidates(root_dir)
    local candidates = {}
    local seen = {}

    local function check_file(path)
        if not seen[path] and vim.fn.filereadable(path) == 1 then
            seen[path] = true
            table.insert(candidates, path)
        end
    end

    -- Common search paths
    local search_dirs = {
        root_dir,
        vim.fs.joinpath(root_dir, "src"),
        vim.fs.joinpath(root_dir, "source"),
    }

    for _, d in ipairs(search_dirs) do
        if vim.fn.isdirectory(d) == 1 then
            local entries = vim.fn.globpath(d, "*unit*.c", false, true)
            for _, f in ipairs(entries) do check_file(f) end

            local unity_entries = vim.fn.globpath(d, "*unity*.c", false, true)
            for _, f in ipairs(unity_entries) do check_file(f) end
        end
    end

    return candidates
end

--- Get the active unity build file for a project root or buffer
--- @param bufnr_or_path number|string|nil
--- @return string|nil
function M.get_unity_file(bufnr_or_path)
    local root = M.get_project_root(bufnr_or_path)

    -- 1. Check in-memory registry
    if active_targets[root] and vim.fn.filereadable(active_targets[root]) == 1 then
        return active_targets[root]
    end

    -- 2. Check persisted state
    local persisted = load_persisted_targets()
    if persisted[root] and vim.fn.filereadable(persisted[root]) == 1 then
        active_targets[root] = persisted[root]
        return persisted[root]
    end

    -- 3. Automatic detection: if project contains exactly one obvious unity file
    local candidates = M.find_candidates(root)
    if #candidates == 1 then
        local found = vim.fs.normalize(candidates[1])
        active_targets[root] = found
        update_user_clangd_config(root, found)
        return found
    end

    return nil
end

--- Resolve a user input string into an existing file path
--- @param input string|nil
--- @param root_dir string
--- @return string|nil, string[] candidates
function M.resolve_file(input, root_dir)
    if not input or input == "" then
        local candidates = M.find_candidates(root_dir)
        if #candidates == 1 then
            return candidates[1], candidates
        end
        return nil, candidates
    end

    -- Trim whitespace
    input = vim.trim(input)

    -- 1. Check exact path as given (absolute or relative to cwd)
    local p1 = vim.fs.normalize(vim.fn.fnamemodify(input, ":p"))
    if vim.fn.filereadable(p1) == 1 then
        return p1, {}
    end

    -- 2. Check relative to current buffer's directory
    local cur_buf_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
    if cur_buf_dir and cur_buf_dir ~= "" then
        local p2 = vim.fs.normalize(vim.fs.joinpath(cur_buf_dir, input))
        if vim.fn.filereadable(p2) == 1 then
            return p2, {}
        end
    end

    -- 3. Check relative to root_dir
    local p3 = vim.fs.normalize(vim.fs.joinpath(root_dir, input))
    if vim.fn.filereadable(p3) == 1 then
        return p3, {}
    end

    -- 4. Check relative to root_dir/src
    local p4 = vim.fs.normalize(vim.fs.joinpath(root_dir, "src", input))
    if vim.fn.filereadable(p4) == 1 then
        return p4, {}
    end

    -- 5. Search by basename or fuzzy match in root_dir
    local base_name = vim.fs.basename(input)
    local pattern = base_name
    local glob_results = vim.fn.globpath(root_dir, "**/" .. pattern, false, true)
    if #glob_results > 0 then
        return vim.fs.normalize(glob_results[1]), glob_results
    end

    -- Fuzzy candidate search: match *unit* or *unity* if input contains unit
    if base_name:lower():find("unit") then
        local candidates = M.find_candidates(root_dir)
        if #candidates > 0 then
            return vim.fs.normalize(candidates[1]), candidates
        end
    end

    return nil, {}
end

--- Restart clangd LSP clients to apply updated compilation options
function M.restart_clangd()
    local clangd_clients = vim.lsp.get_clients({ name = "clangd" })
    for _, client in ipairs(clangd_clients) do
        client:stop()
    end

    -- Reset diagnostics across all buffers
    pcall(vim.diagnostic.reset)

    -- Wait briefly for graceful shutdown, then re-trigger attached buffers
    vim.defer_fn(function()
        local bufs = vim.api.nvim_list_bufs()
        for _, b in ipairs(bufs) do
            if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_is_loaded(b) then
                local ft = vim.bo[b].filetype
                if ft == "c" or ft == "cpp" then
                    vim.api.nvim_buf_call(b, function()
                        pcall(vim.cmd, "edit")
                    end)
                end
            end
        end
    end, 200)
end

--- Set the unity include file for the current project
--- Always writes configuration OUTSIDE the repository (~/.config/clangd/config.yaml)
--- @param filepath string
--- @param opts table|nil
function M.set_unity_file(filepath, opts)
    opts = opts or {}
    local root = M.get_project_root(opts.bufnr)
    filepath = vim.fs.normalize(vim.fn.fnamemodify(filepath, ":p"))

    if vim.fn.filereadable(filepath) ~= 1 then
        vim.notify("Cowabuga: File not readable or does not exist: " .. filepath, vim.log.levels.ERROR)
        return false
    end

    active_targets[root] = filepath

    -- Persist in state json (~/.local/state/nvim/cowabuga_targets.json)
    local persisted = load_persisted_targets()
    persisted[root] = filepath
    save_persisted_targets(persisted)

    -- Persist in global user clangd config OUTSIDE the repository (~/.config/clangd/config.yaml)
    update_user_clangd_config(root, filepath)

    -- Clean any in-repo .clangd if present
    local in_repo_clangd = vim.fs.joinpath(root, ".clangd")
    if vim.fn.filereadable(in_repo_clangd) == 1 then
        local first_lines = vim.fn.readfile(in_repo_clangd, "", 3)
        for _, fl in ipairs(first_lines) do
            if fl:find("Cowabuga") then
                pcall(vim.fn.delete, in_repo_clangd)
                break
            end
        end
    end

    -- Restart LSP to apply flags
    M.restart_clangd()

    local rel_path = vim.fn.fnamemodify(filepath, ":.")
    local user_cfg = get_user_clangd_config_path()
    vim.notify(
        string.format("Cowabuga! Active unity include: %s\nConfig outside repo: %s\nLSP (clangd) restarted.", rel_path, user_cfg),
        vim.log.levels.INFO
    )
    return true
end

--- Clear the unity include file for current project
--- @param bufnr number|nil
function M.clear_unity_file(bufnr)
    local root = M.get_project_root(bufnr)
    active_targets[root] = nil

    local persisted = load_persisted_targets()
    persisted[root] = nil
    save_persisted_targets(persisted)

    remove_user_clangd_config(root)

    M.restart_clangd()
    vim.notify("Cowabuga! Unity include configuration cleared. LSP reverted to default.", vim.log.levels.INFO)
end

--- Display Cowabuga status
--- @param bufnr number|nil
function M.status(bufnr)
    local root = M.get_project_root(bufnr)
    local unity_file = M.get_unity_file(bufnr)
    local clients = vim.lsp.get_clients({ name = "clangd" })
    local user_cfg = get_user_clangd_config_path()

    local lines = {
        "Cowabuga Unity Include Status:",
        "  • Project Root: " .. root,
        "  • Active Unity File: " .. (unity_file or "(none configured)"),
        "  • User Clangd Config (Outside Repo): " .. user_cfg,
        "  • Clangd LSP Clients Running: " .. #clients,
    }

    if unity_file then
        table.insert(lines, "  • Include Dir: " .. vim.fs.dirname(unity_file))
    end

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

--- Command dispatcher for :Cowabuga
--- @param args string
function M.command(args)
    args = vim.trim(args or "")
    local root = M.get_project_root()

    -- Subcommand: status
    if args == "--status" or args == "status" then
        M.status()
        return
    end

    -- Subcommand: clear / off / reset
    if args == "--clear" or args == "off" or args == "clear" or args == "--reset" or args == "none" then
        M.clear_unity_file()
        return
    end

    local file, candidates = M.resolve_file(args, root)
    if not file then
        if #candidates > 1 then
            local msg = "Cowabuga: Multiple unity candidates found. Please specify one:\n"
            for _, c in ipairs(candidates) do
                msg = msg .. "  :Cowabuga " .. vim.fn.fnamemodify(c, ":.") .. "\n"
            end
            vim.notify(msg, vim.log.levels.WARN)
        elseif args ~= "" then
            vim.notify("Cowabuga: Target file not found: '" .. args .. "'.\nUsage: :Cowabuga <path/to/unity_file.c>", vim.log.levels.ERROR)
        else
            vim.notify("Cowabuga: No unity build file (*unit*.c) detected in project.\nUsage: :Cowabuga <path/to/unity_file.c>", vim.log.levels.WARN)
        end
        return
    end

    M.set_unity_file(file)
end

--- Custom completion for :Cowabuga
--- @param arg_lead string
--- @param cmd_line string
--- @param cursor_pos number
--- @return string[]
function M.complete(arg_lead, cmd_line, cursor_pos)
    local subcommands = { "--status", "--clear", "off", "status" }
    local results = {}

    for _, sub in ipairs(subcommands) do
        if sub:find("^" .. vim.pesc(arg_lead)) then
            table.insert(results, sub)
        end
    end

    -- Complete C/C++ files
    local root = M.get_project_root()
    local glob_results = vim.fn.globpath(root, "**/*" .. arg_lead .. "*.c", false, true)
    for _, f in ipairs(glob_results) do
        local rel = vim.fn.fnamemodify(f, ":.")
        table.insert(results, rel)
    end

    return results
end

return M
