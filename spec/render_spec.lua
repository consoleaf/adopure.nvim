local assert = require("luassert.assert")

describe("thread window virtual text anchor", function()
    local main_win
    local render
    local render_ns

    local function fake_thread()
        return {
            id = 1597842,
            status = "active",
            publishedDate = "2026-10-07T13:04:00Z",
            lastUpdatedDate = "2026-10-07T13:10:00Z",
            comments = {
                {
                    id = 1,
                    author = { displayName = "Reviewer" },
                    publishedDate = "2026-10-07T13:04:00Z",
                    content = "please change",
                    commentType = "text",
                },
            },
        }
    end

    ---Simulate the user typing lines at the top of the composer buffer:
    ---an insert at the extmark anchor position that spans multiple lines.
    ---@param bufnr number
    local function type_lines_at_top(bufnr)
        vim.api.nvim_buf_set_text(bufnr, 0, 0, 0, 0, { "first line", "second line" })
    end

    ---@param bufnr number
    ---@return integer|nil row
    local function anchor_row(bufnr)
        render_ns = render_ns or vim.api.nvim_get_namespaces()["adopure-render"]
        local marks = vim.api.nvim_buf_get_extmarks(bufnr, render_ns, 0, -1, {})
        assert.is_truthy(#marks > 0)
        return marks[1][2]
    end

    before_each(function()
        main_win = vim.api.nvim_get_current_win()
        render = require("adopure.render")
    end)

    after_each(function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            if win ~= main_win then
                pcall(vim.api.nvim_win_close, win, true)
            end
        end
    end)

    it("reply block stays anchored at the first line while the user types", function()
        local bufnr = render.render_reply_thread(fake_thread())
        type_lines_at_top(bufnr)
        assert.are.same(0, anchor_row(bufnr))
    end)

    it("new thread block stays anchored at the first line while the user types", function()
        local bufnr = render.render_new_thread({ "selected()" })
        type_lines_at_top(bufnr)
        assert.are.same(0, anchor_row(bufnr))
    end)
end)
