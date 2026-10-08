local assert = require("luassert.assert")

describe("suggested edits", function()
    local main_win
    local thread

    before_each(function()
        main_win = vim.api.nvim_get_current_win()
        thread = require("adopure.thread")
    end)

    after_each(function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            if win ~= main_win then
                pcall(vim.api.nvim_win_close, win, true)
            end
        end
    end)

    describe("build_suggestion_prefill", function()
        it("wraps the selection in a suggestion fence", function()
            local prefill = thread.build_suggestion_prefill({ "first line", "second line" })
            assert.are.same({
                "```suggestion",
                "first line",
                "second line",
                "```",
            }, prefill)
        end)

        it("produces an empty block for an empty selection (deletion proposal)", function()
            local prefill = thread.build_suggestion_prefill({})
            assert.are.same({ "```suggestion", "```" }, prefill)
        end)

        it("keeps the selected lines verbatim, including leading whitespace", function()
            local prefill = thread.build_suggestion_prefill({ "    indented()" })
            assert.are.same({ "```suggestion", "    indented()", "```" }, prefill)
        end)
    end)

    describe("render_new_thread with prefill", function()
        it("writes the prefill into the comment buffer for editing", function()
            local selection = { "old()" }
            local prefill = { "```suggestion", "new()", "```" }
            local bufnr = require("adopure.render").render_new_thread(selection, prefill)
            assert.are.same(prefill, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
        end)

        it("leaves the comment buffer empty without a prefill", function()
            local bufnr = require("adopure.render").render_new_thread({ "old()" }, nil)
            assert.are.same({ "" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
        end)
    end)

    describe("composer entry points", function()
        local state

        before_each(function()
            local bufnr = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "alpha", "beta", "gamma" })
            vim.api.nvim_set_current_buf(bufnr)
            vim.fn.setpos("'<", { bufnr, 1, 1, 0 })
            vim.fn.setpos("'>", { bufnr, 2, 2147483647, 0 })
            state = { comment_creations = {}, root_path = vim.fn.getcwd() }
        end)

        it("suggest_window opens a composer prefilled with the suggestion template", function()
            thread.suggest_window(state, {})
            assert.are.same(1, #state.comment_creations)
            local creation = state.comment_creations[1]
            assert.are.same({ "```suggestion", "alpha", "beta", "```" },
                vim.api.nvim_buf_get_lines(creation.bufnr, 0, -1, false))
            assert.are.same(1, creation.thread_context.rightFileStart.line)
            assert.are.same(2, creation.thread_context.rightFileEnd.line)
        end)

        it("new_thread_window opens an empty composer on the same selection", function()
            thread.new_thread_window(state, {})
            assert.are.same(1, #state.comment_creations)
            local creation = state.comment_creations[1]
            assert.are.same({ "" }, vim.api.nvim_buf_get_lines(creation.bufnr, 0, -1, false))
            assert.are.same(1, creation.thread_context.rightFileStart.line)
        end)
    end)
end)
