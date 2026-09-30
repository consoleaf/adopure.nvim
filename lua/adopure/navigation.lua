---@mod adopure.navigation
---@brief [[
---Navigation between comment thread marks.
---Marks are placed by the plugin on files that have active comment threads,
---including the right-hand side files opened by diffview.
---
---Jump to the next or previous comment thread:
--->vim
--- :AdoPure open next_comment
--- :AdoPure open prev_comment
---<
---When the current file has no further thread in the chosen direction and the
---current window is part of a diffview session, the navigation continues into
---the next (or previous) file of the diffview file panel.
---While a pull request is active, the plugin sets buffer local keymaps for
---both directions (default: `]t` and `[t`; see |adopure.config.meta|).
---@brief ]]
local M = {}

---@private
---Return the diffview view for the current tabpage, if any.
---@return table|nil view
local function get_diffview_view()
    local ok, lib = pcall(require, "diffview.lib")
    if not ok then
        return nil
    end
    local ok_view, view = pcall(lib.get_current_view)
    if not ok_view then
        return nil
    end
    return view
end

---@private
---Move the cursor of the current window to a comment mark, clamped to the
---buffer bounds.
---@param mark table<number, number, number>: extmark_id, row, col
local function set_cursor_to_mark(mark)
    local line_count = vim.api.nvim_buf_line_count(0)
    local row = math.min(mark[2], line_count - 1)
    local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
    vim.api.nvim_win_set_cursor(0, { row + 1, math.min(mark[3], #line) })
end

---@private
---Find the first comment mark strictly after (or before) the cursor position.
---@param direction "next"|"prev"
---@return table|nil mark: extmark_id, row, col
local function find_mark_after_cursor(direction)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]
    local marks = require("adopure.marker").get_comment_marks()
    if direction == "next" then
        for _, mark in ipairs(marks) do
            if mark[2] > row or (mark[2] == row and mark[3] > col) then
                return mark
            end
        end
        return nil
    end
    for i = #marks, 1, -1 do
        local mark = marks[i]
        if mark[2] < row or (mark[2] == row and mark[3] < col) then
            return mark
        end
    end
    return nil
end

---@private
---Return the ordered file entries of the diffview file panel.
---@param view table
---@return table[]: FileEntry[]
local function get_ordered_entries(view)
    local panel = view.panel or view.file_panel
    if not panel then
        return {}
    end
    if type(panel.ordered_file_list) == "function" then
        local ok, entries = pcall(panel.ordered_file_list, panel)
        if ok and entries then
            return entries
        end
    end
    if type(panel.items) == "function" then
        local ok, entries = pcall(panel.items, panel)
        if ok and entries then
            return entries
        end
    end
    return {}
end

---@private
---Return the file entry currently opened in the diffview view, if identifiable.
---@param view table
---@return table|nil file_entry
local function get_current_file_entry(view)
    if type(view.infer_cur_file) == "function" then
        local ok, file_entry = pcall(view.infer_cur_file, view)
        if ok and file_entry then
            return file_entry
        end
    end
    local panel = view.panel or view.file_panel
    if panel then
        return panel.cur_file
    end
    return nil
end

---@private
---Return the active comment threads that target a diffview file entry.
---@param state adopure.AdoState
---@param entry table: FileEntry
---@return adopure.AdoThread[]
local function threads_for_entry(state, entry)
    ---@type adopure.AdoThread[]
    local result = {}
    for _, thread in ipairs(state.pull_request_threads) do
        if thread:is_active_thread() then
            local targeted = thread:targeted_file_path()
            if targeted and entry.path == targeted.filename then
                table.insert(result, thread)
            end
        end
    end
    return result
end

---@private
---Find the window that displays a diffview file entry.
---@param entry table: FileEntry
---@return number|nil winid
local function find_entry_window(entry)
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(winid) then
            local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(winid))
            if name == entry.absolute_path or name == entry.path then
                return winid
            end
        end
    end
    return nil
end

---@private
---Move the cursor to the first (or last) comment thread of a file entry once
---diffview opened it. Retries with a delay, since diffview opens files
---asynchronously.
---@param entry table: FileEntry
---@param threads adopure.AdoThread[]
---@param direction "next"|"prev"
---@param attempts number
local function jump_into_entry(entry, threads, direction, attempts)
    vim.defer_fn(function()
        local winid = find_entry_window(entry)
        if not winid then
            if attempts > 0 then
                jump_into_entry(entry, threads, direction, attempts - 1)
            end
            return
        end
        local bufnr = vim.api.nvim_win_get_buf(winid)
        local marks = require("adopure.marker").get_comment_marks(bufnr)
        if #marks > 0 then
            local mark = direction == "next" and marks[1] or marks[#marks]
            local line_count = vim.api.nvim_buf_line_count(bufnr)
            local row = math.min(mark[2], line_count - 1)
            local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
            vim.api.nvim_win_set_cursor(winid, { row + 1, math.min(mark[3], #line) })
            return
        end
        local thread = direction == "next" and threads[1] or threads[#threads]
        local context = thread:thread_context()
        local line = context and context.rightFileStart and context.rightFileStart.line or 1
        vim.api.nvim_win_set_cursor(winid, { math.min(line, vim.api.nvim_buf_line_count(bufnr)), 0 })
    end, 50)
end

---@private
---Open the next (or previous) diffview file that has active comment threads.
---@param state adopure.AdoState
---@param direction "next"|"prev"
---@return boolean: true when a file with comment threads was opened
local function open_file_with_threads(state, direction)
    local view = get_diffview_view()
    if not view then
        return false
    end

    local entries = get_ordered_entries(view)
    local current = get_current_file_entry(view)
    local current_index = 0
    for i, entry in ipairs(entries) do
        if entry == current or (current and entry.path == current.path) then
            current_index = i
            break
        end
    end

    ---@type integer[]
    local order = {}
    if direction == "next" then
        for i = current_index + 1, #entries do
            table.insert(order, i)
        end
        for i = 1, current_index do
            table.insert(order, i)
        end
    else
        for i = current_index - 1, 1, -1 do
            table.insert(order, i)
        end
        for i = #entries, current_index + 1, -1 do
            table.insert(order, i)
        end
    end

    for _, i in ipairs(order) do
        local entry = entries[i]
        local threads = threads_for_entry(state, entry)
        if #threads > 0 then
            local opened
            if type(view.set_file) == "function" then
                opened = pcall(view.set_file, view, entry, true)
            elseif type(view._set_file) == "function" then
                opened = pcall(view._set_file, view, entry)
            end
            if opened then
                jump_into_entry(entry, threads, direction, 20)
                return true
            end
            return false
        end
    end
    return false
end

---@private
---Jump to the next or previous comment thread.
---Searches the current buffer first; when exhausted, continues into the next
---(or previous) diffview file that has active comment threads.
---@param state adopure.AdoState
---@param direction "next"|"prev"
function M.jump(state, direction)
    if not (state and state.pull_request_threads and #state.pull_request_threads > 0) then
        vim.notify("No comment threads loaded; run :AdoPure load threads first;", 3)
        return
    end
    local mark = find_mark_after_cursor(direction)
    if mark then
        set_cursor_to_mark(mark)
        return
    end
    if not open_file_with_threads(state, direction) then
        vim.notify("No comment thread found in this direction;", 3)
    end
end

---Jump to the next comment thread in the current file.
---When in diffview and no further threads exist in the current file,
---continues into the next file that has comment threads.
---@param state adopure.AdoState
---@param _ table
function M.jump_to_next_comment(state, _)
    M.jump(state, "next")
end

---Jump to the previous comment thread in the current file.
---When in diffview and no earlier threads exist in the current file,
---continues into the previous file that has comment threads.
---@param state adopure.AdoState
---@param _ table
function M.jump_to_prev_comment(state, _)
    M.jump(state, "prev")
end

return M
