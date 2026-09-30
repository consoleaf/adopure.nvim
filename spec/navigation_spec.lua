local assert = require("luassert.assert")

describe("Comment navigation", function()
    local navigation = require("adopure.navigation")
    local namespace = vim.api.nvim_create_namespace("adopure-marker")

    ---Create a scratch buffer with content and an optional name.
    ---@param lines string[]
    ---@param name string|nil
    ---@return number bufnr
    local function make_buffer(lines, name)
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        if name then
            vim.api.nvim_buf_set_name(bufnr, name)
        end
        return bufnr
    end

    ---Create an active comment thread fixture.
    ---@param id number
    ---@param path string
    ---@param line number
    ---@param offset number
    ---@return adopure.AdoThread
    local function make_thread(id, path, line, offset)
        return require("adopure.types.ado_thread").AdoThread:new({
            id = id,
            status = "active",
            isDeleted = false,
            comments = { { content = "comment " .. id } },
            threadContext = {
                filePath = "/" .. path,
                rightFileStart = { line = line, offset = offset },
                rightFileEnd = { line = line, offset = offset + 3 },
            },
        })
    end

    ---Place a comment mark fixture, mirroring what adopure.marker does.
    ---@param bufnr number
    ---@param id number
    ---@param row number
    ---@param col number
    local function place_mark(bufnr, id, row, col)
        vim.api.nvim_buf_set_extmark(bufnr, namespace, row, col, {
            id = id,
            end_row = row,
            end_col = col + 3,
            hl_group = "Search",
            sign_text = "󰅺 ",
            sign_hl_group = "Todo",
        })
    end

    ---Capture vim.notify calls while running a function.
    ---@param callback function
    ---@return table[]: { msg: string, level: number }[]
    local function capture_notifications(callback)
        local notifications = {}
        local original_notify = vim.notify
        vim.notify = function(msg, level)
            table.insert(notifications, { msg = msg, level = level })
        end
        callback()
        vim.notify = original_notify
        return notifications
    end

    it("does not jump when comment threads are not loaded", function()
        local notifications = capture_notifications(function()
            navigation.jump_to_next_comment({}, {})
        end)
        assert.are.same(#notifications, 1)
        assert.truthy(notifications[1].msg:find("load threads"))
    end)

    it("jumps to the next and previous comment mark in the current buffer", function()
        local bufnr = make_buffer(vim.split(("line\n"):rep(20), "\n"))
        vim.api.nvim_win_set_buf(0, bufnr)
        place_mark(bufnr, 1, 4, 0)
        place_mark(bufnr, 2, 9, 0)
        place_mark(bufnr, 3, 14, 0)
        local state = { pull_request_threads = { make_thread(1, "file.txt", 5, 1) } }

        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        navigation.jump_to_next_comment(state, {})
        assert.are.same(vim.api.nvim_win_get_cursor(0)[1], 5)
        navigation.jump_to_next_comment(state, {})
        assert.are.same(vim.api.nvim_win_get_cursor(0)[1], 10)
        navigation.jump_to_next_comment(state, {})
        assert.are.same(vim.api.nvim_win_get_cursor(0)[1], 15)
        navigation.jump_to_prev_comment(state, {})
        assert.are.same(vim.api.nvim_win_get_cursor(0)[1], 10)
    end)

    it("jumps between comment marks on the same line", function()
        local lines = {}
        for i = 1, 20 do
            lines[i] = string.rep("a", 30)
        end
        local bufnr = make_buffer(lines)
        vim.api.nvim_win_set_buf(0, bufnr)
        place_mark(bufnr, 1, 4, 0)
        place_mark(bufnr, 2, 4, 12)
        local state = { pull_request_threads = { make_thread(1, "file.txt", 5, 1) } }

        vim.api.nvim_win_set_cursor(0, { 5, 2 })
        navigation.jump_to_next_comment(state, {})
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same(cursor[1], 5)
        assert.are.same(cursor[2], 12)
        navigation.jump_to_prev_comment(state, {})
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same(cursor[1], 5)
        assert.are.same(cursor[2], 0)
    end)

    it("notifies when no comment mark remains in the chosen direction", function()
        local bufnr = make_buffer(vim.split(("line\n"):rep(20), "\n"))
        vim.api.nvim_win_set_buf(0, bufnr)
        place_mark(bufnr, 1, 4, 0)
        local state = { pull_request_threads = { make_thread(1, "file.txt", 5, 1) } }

        vim.api.nvim_win_set_cursor(0, { 16, 0 })
        local notifications = capture_notifications(function()
            navigation.jump_to_next_comment(state, {})
        end)
        assert.are.same(#notifications, 1)
        assert.are.same(vim.api.nvim_win_get_cursor(0)[1], 16)
    end)

    it("continues into the next diffview file with comment threads", function()
        local buf_a = make_buffer(vim.split(("file a\n"):rep(20), "\n"), "/repo/file_a.txt")
        local buf_b = make_buffer(vim.split(("file b\n"):rep(20), "\n"), "/repo/file_b.txt")
        place_mark(buf_b, 7, 6, 0)
        local thread_b = make_thread(7, "file_b.txt", 7, 1)
        local state = { root_path = "/repo", pull_request_threads = { thread_b } }

        local entries = {
            { path = "file_a.txt", absolute_path = "/repo/file_a.txt" },
            { path = "file_b.txt", absolute_path = "/repo/file_b.txt" },
        }
        local view = {
            panel = {
                cur_file = entries[1],
                ordered_file_list = function(_)
                    return entries
                end,
            },
            infer_cur_file = function(_)
                return entries[1]
            end,
            set_file = function(_, entry, _focus)
                vim.api.nvim_win_set_buf(0, entry.absolute_path == "/repo/file_b.txt" and buf_b or buf_a)
                return true
            end,
        }
        package.loaded["diffview.lib"] = { get_current_view = function()
            return view
        end }

        vim.api.nvim_win_set_buf(0, buf_a)
        vim.api.nvim_win_set_cursor(0, { 19, 0 })
        navigation.jump_to_next_comment(state, {})
        local opened = vim.wait(500, function()
            return vim.api.nvim_buf_get_name(0) == "/repo/file_b.txt"
                and vim.api.nvim_win_get_cursor(0)[1] == 7
        end)
        package.loaded["diffview.lib"] = nil
        assert.truthy(opened, "expected the navigation to open file_b.txt at line 7")
    end)
end)
