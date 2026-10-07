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
end)
