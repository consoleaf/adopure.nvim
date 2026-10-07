---@mod adopure.config.meta
---@brief [[
---The plugin is configured by assigning an adopure.Config table to vim.g.adopure.
--->lua
--- vim.g.adopure = {}
---<
---There is no mechanism built-in to securely load secrets.
---If you have a cli command that will produce the secret, consider doing something like this:
--->lua
--- local nio = require("nio")
--- nio.run(function()
---     local secret_job = nio.process.run({ cmd = "pass", args = { "show", "my_pat_token_secret_name"} })
---     vim.g.adopure = { pat_token = secret_job.stdout.read():sub(1, -2) }
--- end)
---<
---Alternatively, you can set it as environment variable.
---@brief ]]
---
---@class adopure.Highlights
---@field active? string Highlight for lines with active comments.
---@field active_sign? string Highlight for sign indicating active comments.
---@field inactive? string Highlight for lines with inactive comments.
---@field inactive_sign? string Highlight for sign indicating in active comments.

---@class adopure.Keymaps
---Keybinding to jump to the next comment thread; buffer local while a pull
---request is active. Set to false to disable.
---@field next_comment? string|false
---Keybinding to jump to the previous comment thread; buffer local while a pull
---request is active. Set to false to disable.
---@field prev_comment? string|false

---@class adopure.Config
---If not provided, attempt to use AZURE_DEVOPS_EXT_PAT environment variable.
---If no environment variable and no config is set, requests are sent without
---an Authorization header; that only works when authentication is injected
---upstream (e.g. a corporate proxy adding Kerberos auth).
---@field pat_token? string Personal Access Token to access Azure DevOps.
---Optional proxy for all api calls, passed to curl as --proxy
---("[protocol://]host[:port]"). The HTTPS_PROXY/HTTP_PROXY environment
---variables are honored by curl itself and need no configuration.
---@field proxy? string
---@field hl_groups? adopure.Highlights Highlight groups to apply.
---List with preferred remotes to extract Azure DevOps context from.
---Remotes are elected among the following options:
---1. Any remote in this list can be picked, non-deterministically.
---2. Any Azure DevOps remote.
---3. Any remote. If the remote is not an Azure DevOps remote, the plugin will not work.
---@field preferred_remotes? string[]
---@field filter_my_pull_requests? boolean Fetches only pull requests assigned to me, my team or created by me.
---Buffer local keymaps set on review buffers while a pull request is active.
---@field keymaps? adopure.Keymaps

local config = {}

---@type adopure.Config | fun():adopure.Config | nil
vim.g.adopure = vim.g.adopure

return config
