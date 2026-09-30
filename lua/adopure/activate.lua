local M = {}

---@param pull_request adopure.PullRequest
local function confirm_open_in_diffview(pull_request)
    vim.ui.input({ prompt = "Open in diffview? <CR> / <ESC>" }, function(input)
        if not input then
            return
        end
        local merge_base = require("adopure.git").get_merge_base(pull_request)
        vim.cmd(":DiffviewOpen " .. merge_base)
    end)
end

---Whether a buffer belongs to the pull request review surface: a diffview
---buffer, or a file inside the repository.
---@param state adopure.AdoState
---@param file string
---@return boolean
local function is_review_buffer(state, file)
    if file:find("^diffview://") then
        return true
    end
    local absolute = vim.fs.normalize(vim.fn.fnamemodify(file, ":p"))
    local root = vim.fs.normalize(state.root_path)
    return root ~= "" and absolute:sub(1, #root) == root
end

---@param bufnr number
---@param state adopure.AdoState
local function buffer_keymaps(bufnr, state)
    local keymaps = require("adopure.config.internal").keymaps
    ---@param lhs string|boolean|nil
    ---@param rhs function
    ---@param desc string
    local function set_keymap(lhs, rhs, desc)
        if lhs then
            vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc, silent = true, nowait = true })
        end
    end
    set_keymap(keymaps.next_comment, function()
        require("adopure.navigation").jump_to_next_comment(state, {})
    end, "AdoPure: jump to next comment thread")
    set_keymap(keymaps.prev_comment, function()
        require("adopure.navigation").jump_to_prev_comment(state, {})
    end, "AdoPure: jump to previous comment thread")
end

---@param bufnr number
local function clear_buffer_keymaps(bufnr)
    local keymaps = require("adopure.config.internal").keymaps
    for _, lhs in ipairs({ keymaps.next_comment, keymaps.prev_comment }) do
        if lhs then
            pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
        end
    end
end

---@param state adopure.AdoState
local function buffer_marker_autocmd(state)
    local augroup = vim.api.nvim_create_augroup("adopure.nvim", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        group = augroup,
        callback = function(args)
            if state.pull_request_threads and args.file ~= "" then
                require("adopure.marker").clear_removed_comment_marks(args.buf, state.pull_request_threads)
                require("adopure.marker").create_new_comment_marks(args.buf, state, args.file)
                if is_review_buffer(state, args.file) then
                    buffer_keymaps(args.buf, state)
                end
            end
        end,
    })
end

function M.disabled_buffer_marker_autocmd()
    local augroup = vim.api.nvim_create_augroup("adopure.nvim", { clear = true })
    local namespace = vim.api.nvim_create_namespace("adopure-marker")
    vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
    clear_buffer_keymaps(0)
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        group = augroup,
        callback = function(args)
            vim.api.nvim_buf_clear_namespace(args.buf, namespace, 0, -1)
            clear_buffer_keymaps(args.buf)
        end,
    })
end

---@param state adopure.AdoState
function M.activate_pull_request_context(state)
    require("adopure.marker").clear_removed_comment_marks(0, state.pull_request_threads)
    require("adopure.git").confirm_checkout_and_open(state.active_pull_request, function()
        confirm_open_in_diffview(state.active_pull_request)
    end)
    buffer_marker_autocmd(state)
end
return M
