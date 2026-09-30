local M = {}

local remote_markers = { "azure.com", "visualstudio.com", "ssh://", "@ssh", "_git/" }

---@param remote_stdout string[]
---@return string remote
local function elect_remote(remote_stdout)
    local preferred_remotes = require("adopure.config.internal").preferred_remotes
    for _, remote_line in ipairs(remote_stdout) do
        local remote_name = vim.split(remote_line, "\t")[1]
        if vim.tbl_contains(preferred_remotes, remote_name) then
            return remote_line
        end
    end
    for _, remote_line in ipairs(remote_stdout) do
        for _, marker in ipairs(remote_markers) do
            if remote_line:find(marker, 1, true) then
                return remote_line
            end
        end
    end
    vim.notify("adopure unable to elect azure devops remote url; taking the first", 3)
    return remote_stdout[1]
end

---Parse any Azure DevOps remote url into api parts. Handles cloud and
---on-prem (Azure DevOps Server / TFS) remotes in ssh, scp-like and https form:
---  ssh://[user@]host[:port]/v3/org/project/repo                  (cloud)
---  ssh://[user@]host[:port]/[vdir/]collection/project/_git/repo  (on-prem)
---  user@host:v3/org/project/repo                                 (cloud, scp-like)
---  user@host:[vdir/]collection/project/_git/repo                 (on-prem, scp-like)
---  https://[user@]host[:port]/[vdir/]collection/project/_git/repo
---  https://org.visualstudio.com/project/_git/repo
---Ssh ports are dropped (the api is served over https), https ports are kept.
---@param url string
---@return string|nil organization_url
---@return string|nil project_name
---@return string|nil repository_name
local function parse_remote_url(url)
    local rest, is_ssh
    if url:find("^ssh://") then
        rest, is_ssh = url:sub(7), true
    elseif url:find("^https?://") then
        rest = url:gsub("^https?://", "")
    elseif url:find("@") and url:find(":") then
        -- scp-like syntax: rewrite "user@host:path" into "host/path"
        rest, is_ssh = url:gsub("^[^@]+@", ""):gsub(":", "/", 1), true
    else
        return nil
    end
    rest = rest:gsub("^[^/@]+@", "")
    local authority = rest:match("^([^/]+)")
    if not authority then
        return nil
    end
    local path = rest:sub(#authority + 1):gsub("^/", "", 1)
    local host, port = authority:match("^([^:]+):(%d+)$")
    if host then
        authority = host .. (is_ssh and "" or ":" .. port)
    end
    local segs = vim.split(path, "/")
    local organization_url, project_name, repository_name
    if segs[1] == "v3" and segs[2] and segs[3] and segs[4] then
        organization_url = "https://" .. authority:gsub("^ssh%.", "") .. "/" .. segs[2] .. "/"
        project_name = segs[3]
        repository_name = segs[4]
    elseif segs[4] == "_git" and segs[2] and segs[3] and segs[5] then
        -- on-prem with virtual directory: vdir/collection/project/_git/repo
        organization_url = "https://" .. authority .. "/" .. segs[1] .. "/" .. segs[2] .. "/"
        project_name = segs[3]
        repository_name = segs[5]
    elseif segs[3] == "_git" and segs[1] and segs[2] and segs[4] then
        -- cloud https or on-prem without virtual directory: collection/project/_git/repo
        organization_url = "https://" .. authority .. "/" .. segs[1] .. "/"
        project_name = segs[2]
        repository_name = segs[4]
    elseif segs[2] == "_git" and segs[1] and segs[3] then
        -- visualstudio.com form: the organization is the host prefix
        organization_url = "https://" .. authority .. "/"
        project_name = segs[1]
        repository_name = segs[3]
    end
    return organization_url, project_name, repository_name
end

---@param remote_stdout string
---@param root_path string
---@return string organization_url
---@return string project_name
---@return string repository_name
---@return string root_path
local function extract_git_details(remote_stdout, root_path)
    local url_with_type = vim.split(remote_stdout, "\t")[2]
    local url = vim.split(url_with_type, " ")[1]
    local organization_url, project_name, repository_name = parse_remote_url(url)
    if not organization_url then
        error("adopure could not parse azure devops remote url: " .. url)
    end
    return organization_url, project_name, repository_name, root_path
end

---Get config from git remote
---@return string organization_url
---@return string project_name
---@return string repository_name
---@return string root_path
function M.get_remote_config()
    local get_remotes = require("plenary.job"):new({ ---@diagnostic disable-line: missing-fields
        command = "git",
        args = { "remote", "-v" },
        cwd = ".",
    })
    local get_root = require("plenary.job"):new({ ---@diagnostic disable-line: missing-fields
        command = "git",
        args = { "rev-parse", "--show-toplevel" },
        cwd = ".",
    })

    get_remotes:start()
    get_root:start()
    local remote_result = require("adopure.utils").await_result(get_remotes)
    local root_result = require("adopure.utils").await_result(get_root)
    vim.iter({ remote_result, root_result })
        :filter(function(result) ---@param result adopure.JobResult
            return not not result.stderr[1]
        end)
        :each(function(result) ---@param result adopure.JobResult
            if not result.stdout[1] then
                error(result.stderr[1])
            end
            vim.notify(result.stderr[1], 3)
        end)
    assert(remote_result.stdout[1], "No remote found to extract details;")
    assert(root_result.stdout[1], "No root location found in repo;")
    local elected_remote = elect_remote(remote_result.stdout)
    return extract_git_details(elected_remote, root_result.stdout[1])
end

---Get merge base commit
---@param pull_request adopure.PullRequest
---@return string merge_base
function M.get_merge_base(pull_request)
    local get_merge_base = require("plenary.job"):new({ ---@diagnostic disable-line: missing-fields
        command = "git",
        args = {
            "merge-base",
            pull_request.lastMergeSourceCommit.commitId,
            pull_request.lastMergeTargetCommit.commitId,
        },
        cwd = ".",
    })
    get_merge_base:start()
    local result = require("adopure.utils").await_result(get_merge_base)
    if result.stderr[1] then
        if not result.stdout[1] then
            error(result.stderr[1])
        end
        vim.notify(result.stderr[1], 3)
    end
    assert(result.stdout[1], "No merge base found;")
    return result.stdout[1]
end

---@param pull_request adopure.PullRequest
---@param open_callable function
function M.confirm_checkout_and_open(pull_request, open_callable)
    local Job = require("plenary.job")
    vim.ui.input({ prompt = "Try to checkout pull request source branch? <CR> / <ESC>" }, function(input)
        if not input then
            open_callable()
            return
        end
        local git_checkout_remote_job = Job:new({ ---@diagnostic disable-line: missing-fields
            command = "git",
            args = { "checkout", pull_request.lastMergeSourceCommit.commitId },
            cwd = ".",
            on_exit = function(j, return_val)
                if return_val ~= 0 then
                    error("Checkout failed: " .. vim.inspect(j:result()))
                end
            end,
        })

        git_checkout_remote_job:start()
        open_callable()
    end)
end

return M
