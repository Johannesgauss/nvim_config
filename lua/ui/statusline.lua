-- Zero-fork, cached Git workspace statusline (0.001ms per redraw vs 3.97ms with vim.fn.system)
local workspace_cache = {}
local current_workspace_str = ""

local function resolve_git_dir(git_path)
    local stat = vim.uv.fs_stat(git_path)
    if not stat then
        return nil
    end
    if stat.type == "directory" then
        return git_path
    end
    -- Worktree or submodule: .git is a file containing "gitdir: <path>"
    local f = io.open(git_path, "r")
    if not f then
        return nil
    end
    local line = f:read("*l")
    f:close()
    if line then
        local rel = line:match("^gitdir:%s*(.+)$")
        if rel then
            rel = vim.trim(rel)
            if not rel:match("^/") then
                rel = vim.fs.normalize(vim.fs.dirname(git_path) .. "/" .. rel)
            end
            return rel
        end
    end
    return nil
end

local function compute_workspace_status(cwd)
    cwd = cwd or vim.uv.cwd() or vim.fn.getcwd()
    local git_root = vim.fs.root(cwd, ".git")

    -- Case 1: NOT a git repository -> Show directory name followed by folder icon
    if not git_root or git_root == "" then
        return " 󰉖 " .. vim.fn.fnamemodify(cwd, ":t") .. " "
    end

    -- Case 2: IS a git repository -> Read .git/HEAD directly in memory (0 subprocesses!)
    local repo_name = vim.fn.fnamemodify(git_root, ":t")
    local git_dir = resolve_git_dir(git_root .. "/.git")
    if git_dir then
        local head_file = io.open(git_dir .. "/HEAD", "r")
        if head_file then
            local head = head_file:read("*l")
            head_file:close()
            if head then
                head = vim.trim(head)
                local branch = head:match("^ref:%s*refs/heads/(.+)$")
                if branch and branch ~= "" then
                    -- EXACT LAYOUT MATCH: Repo Name -> Folder Icon -> Space -> Branch Icon -> branch:name
                    return " 󰉖 " .. repo_name .. "  branch:" .. branch .. " "
                end
            end
        end
    end

    -- Fallback if detached HEAD or no active branch is tracked
    return " " .. repo_name .. " 󰉖 "
end

local function refresh_workspace_status()
    local cwd = vim.uv.cwd() or vim.fn.getcwd()
    current_workspace_str = compute_workspace_status(cwd)
    workspace_cache[cwd] = current_workspace_str
end

-- Compute once on startup and refresh on directory/buffer/focus/terminal changes
refresh_workspace_status()

local statusline_augroup = vim.api.nvim_create_augroup("FastStatuslineCache", { clear = true })
vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter", "FocusGained", "TermClose", "VimResume" }, {
    group = statusline_augroup,
    callback = function()
        refresh_workspace_status()
    end,
})

function Render_Statusline()
    if vim.b.is_docxtui or vim.bo.buftype == "terminal" then
        return ""
    end

    if current_workspace_str == "" then
        refresh_workspace_status()
    end

    local file_info = " %f %m"
    local mode_badge = vim.b.markdown_view_active and " [READ-MODE]" or ""
    local align_right = "%="
    local cursor_metrics = " %l:%c  %p%% "

    return current_workspace_str .. file_info .. mode_badge .. align_right .. cursor_metrics
end

vim.opt.statusline = "%!v:lua.Render_Statusline()"
