local assert = require("luassert.assert")
local plenary_new_job = require("plenary.job").new
local remotes = {
    first_fetch = "first\tgit@ssh.dev.azure.com:v3/first_org/first_project.nvim/first_repo.nvim (fetch)",
    first_push = "first\tgit@ssh.dev.azure.com:v3/first_org/first_project.nvim/first_repo.nvim (push)",
    git_fetch = "origin\tgit@github.com:Willem-J-an/adopure.nvim.git (fetch)",
    git_push = "origin\tgit@github.com:Willem-J-an/adopure.nvim.git (push)",
    second_fetch = "second\thttps://second_org@dev.azure.com/second_org/second_project/_git/second_repo (fetch)",
    second_push = "second\thttps://second_org@dev.azure.com/second_org/second_project/_git/second_repo (push)",
    third_fetch = "third\thttps://dev.azure.com/third_org/third_project/_git/third_repo (fetch)",
    third_push = "third\thttps://dev.azure.com/third_org/third_project/_git/third_repo (push)",
    onprem_ssh_fetch = "onprem\tssh://ado.example.com:22/tfs/Collection/Team/_git/Repo (fetch)",
    onprem_ssh_push = "onprem\tssh://ado.example.com:22/tfs/Collection/Team/_git/Repo (push)",
    onprem_scp_fetch = "onprem_scp\tgit@ado.example.com:tfs/Collection/Team/_git/Repo (fetch)",
    onprem_scp_push = "onprem_scp\tgit@ado.example.com:tfs/Collection/Team/_git/Repo (push)",
    onprem_https_fetch = "onprem_https\thttps://ado.example.com/tfs/Collection/Team/_git/Repo (fetch)",
    onprem_https_push = "onprem_https\thttps://ado.example.com/tfs/Collection/Team/_git/Repo (push)",
    cloud_ssh_fetch = "cloud\tssh://git@ssh.dev.azure.com:443/v3/cloud_org/cloud_project/cloud_repo (fetch)",
    cloud_ssh_push = "cloud\tssh://git@ssh.dev.azure.com:443/v3/cloud_org/cloud_project/cloud_repo (push)",
    vs_fetch = "vs\thttps://vs_org.visualstudio.com/vs_project/_git/vs_repo (fetch)",
    vs_push = "vs\thttps://vs_org.visualstudio.com/vs_project/_git/vs_repo (push)",
    onprem_novdir_fetch = "novdir\tssh://ado.example.com:22/Collection9/Team9/_git/Repo9 (fetch)",
    onprem_novdir_push = "novdir\tssh://ado.example.com:22/Collection9/Team9/_git/Repo9 (push)",
}

describe("get remote config", function()
    ---@param remote_stdout string[]
    local function mock_git_remote(remote_stdout)
        require("plenary.job").new = function(_1, _2) ---@diagnostic disable-line duplicate-set-field
            local _ = _1 and _2
            return {
                start = function(_) end,
                result = function(_)
                    return remote_stdout
                end,
                stderr_result = function(_)
                    return {}
                end,
            }
        end
    end

    it("returns preferred ssh details", function()
        require("adopure.config.internal").preferred_remotes = { "first" }
        mock_git_remote(vim.tbl_values(remotes))
        local organization_url, project_name, repository_name = require("adopure.git").get_remote_config()
        assert.are.same("https://dev.azure.com/first_org/", organization_url)
        assert.are.same("first_project.nvim", project_name)
        assert.are.same("first_repo.nvim", repository_name)
    end)

    it("returns preferred https details with user", function()
        require("adopure.config.internal").preferred_remotes = { "second" }
        mock_git_remote(vim.tbl_values(remotes))
        local organization_url, project_name, repository_name = require("adopure.git").get_remote_config()
        assert.are.same("https://dev.azure.com/second_org/", organization_url)
        assert.are.same("second_project", project_name)
        assert.are.same("second_repo", repository_name)
    end)


    it("returns preferred https details without user", function()
        require("adopure.config.internal").preferred_remotes = { "third" }
        mock_git_remote(vim.tbl_values(remotes))
        local organization_url, project_name, repository_name = require("adopure.git").get_remote_config()
        assert.are.same("https://dev.azure.com/third_org/", organization_url)
        assert.are.same("third_project", project_name)
        assert.are.same("third_repo", repository_name)
    end)

    it("returns on-prem ssh details with port and virtual directory", function()
        require("adopure.config.internal").preferred_remotes = { "onprem" }
        mock_git_remote(vim.tbl_values(remotes))
        local organization_url, project_name, repository_name = require("adopure.git").get_remote_config()
        assert.are.same("https://ado.example.com/tfs/Collection/", organization_url)
        assert.are.same("Team", project_name)
        assert.are.same("Repo", repository_name)
    end)

    it("returns on-prem scp-like details with virtual directory", function()
        require("adopure.config.internal").preferred_remotes = { "onprem_scp" }
        mock_git_remote(vim.tbl_values(remotes))
        local organization_url, project_name, repository_name = require("adopure.git").get_remote_config()
        assert.are.same("https://ado.example.com/tfs/Collection/", organization_url)
        assert.are.same("Team", project_name)
        assert.are.same("Repo", repository_name)
    end)

    it("returns on-prem https details with virtual directory", function()
        require("adopure.config.internal").preferred_remotes = { "onprem_https" }
        mock_git_remote(vim.tbl_values(remotes))
        local organization_url, project_name, repository_name = require("adopure.git").get_remote_config()
        assert.are.same("https://ado.example.com/tfs/Collection/", organization_url)
        assert.are.same("Team", project_name)
        assert.are.same("Repo", repository_name)
    end)

    it("returns cloud ssh url details with user and port", function()
        require("adopure.config.internal").preferred_remotes = { "cloud" }
        mock_git_remote(vim.tbl_values(remotes))
        local organization_url, project_name, repository_name = require("adopure.git").get_remote_config()
        assert.are.same("https://dev.azure.com/cloud_org/", organization_url)
        assert.are.same("cloud_project", project_name)
        assert.are.same("cloud_repo", repository_name)
    end)

    it("returns visualstudio.com details", function()
        require("adopure.config.internal").preferred_remotes = { "vs" }
        mock_git_remote(vim.tbl_values(remotes))
        local organization_url, project_name, repository_name = require("adopure.git").get_remote_config()
        assert.are.same("https://vs_org.visualstudio.com/", organization_url)
        assert.are.same("vs_project", project_name)
        assert.are.same("vs_repo", repository_name)
    end)

    it("returns on-prem ssh details without virtual directory", function()
        require("adopure.config.internal").preferred_remotes = { "novdir" }
        mock_git_remote(vim.tbl_values(remotes))
        local organization_url, project_name, repository_name = require("adopure.git").get_remote_config()
        assert.are.same("https://ado.example.com/Collection9/", organization_url)
        assert.are.same("Team9", project_name)
        assert.are.same("Repo9", repository_name)
    end)

    it("elects azure devops remote without preference", function()
        require("adopure.config.internal").preferred_remotes = {}
        mock_git_remote({ remotes.git_fetch, remotes.onprem_ssh_fetch, remotes.git_push, remotes.onprem_ssh_push })
        local organization_url, project_name, repository_name = require("adopure.git").get_remote_config()
        assert.are.same("https://ado.example.com/tfs/Collection/", organization_url)
        assert.are.same("Team", project_name)
        assert.are.same("Repo", repository_name)
    end)

    it("errors loudly on unparseable remote", function()
        require("adopure.config.internal").preferred_remotes = { "origin" }
        mock_git_remote({ remotes.git_fetch, remotes.git_push })
        assert.has_error(function()
            require("adopure.git").get_remote_config()
        end)
    end)

    after_each(function()
        require("plenary.job").new = plenary_new_job
    end)
end)
