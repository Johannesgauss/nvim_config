local function run_git_cmd(cmd)
    local result = vim.fn.system(cmd)
    return string.gsub(result, "[\r\n]", "")
end

local function get_workspace_status()
    local git_root = run_git_cmd("git rev-parse --show-toplevel 2>/dev/null")
    
    -- Case 1: NOT a git repository -> Show directory name followed by folder icon
    if git_root == "" then
        local cwd = vim.fn.getcwd()
        return " 󰉖 " .. vim.fn.fnamemodify(cwd, ":t") .. " "
    end

    -- Case 2: IS a git repository
    local repo_name = vim.fn.fnamemodify(git_root, ":t")
    local is_work_tree = run_git_cmd("git rev-parse --is-inside-work-tree 2>/dev/null")
    
    if is_work_tree == "true" then
        local branch = run_git_cmd("git branch --show-current 2>/dev/null")
        if branch ~= "" then
            -- EXACT LAYOUT MATCH: Repo Name -> Folder Icon -> Space -> Branch Icon -> branch:name
            return " 󰉖 " .. repo_name .. "  branch:" .. branch .. " │"
        end
    end
    
    -- Fallback if no active branch is tracked
    return " " .. repo_name .. " 󰉖 "
end

function Render_Statusline()
    local workspace = get_workspace_status()
    local file_info = " %f %m"
    local align_right = "%="
    local cursor_metrics = " %l:%c │ %p%% "

    return table.concat({
        workspace,
        file_info,
        align_right,
        cursor_metrics
    })
end

vim.opt.statusline = "%!v:lua.Render_Statusline()"
