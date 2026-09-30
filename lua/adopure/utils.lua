local M = {}
---@class adopure.JobResult
---@field stdout string[]
---@field stderr string[]

local utc_offset_seconds

---Offset in seconds between local time and utc on this machine (cached).
---Positive east of utc.
---@return number
local function get_utc_offset()
    if not utc_offset_seconds then
        local now = os.time()
        utc_offset_seconds = os.difftime(now, os.time(os.date("!*t", now)))
    end
    return utc_offset_seconds
end

---Format an Azure DevOps utc timestamp (e.g. "2026-09-30T11:22:33.97Z")
---as local time. Returns "" for nil or unparsable input instead of erroring.
---@param iso_date string|nil
---@param fmt string|nil os.date format string, defaults to "%Y-%m-%d %H:%M"
---@return string formatted_date
function M.format_ado_date(iso_date, fmt)
    if type(iso_date) ~= "string" then
        return ""
    end
    local year, month, day, hour, minute, second =
        iso_date:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not year then
        return ""
    end
    local epoch = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(minute),
        sec = tonumber(second),
    }) + get_utc_offset()
    return os.date(fmt or "%Y-%m-%d %H:%M", epoch)
end

--- Await result of plenary job
---@diagnostic disable-next-line: undefined-doc-name
---@param job Job
---@return adopure.JobResult
function M.await_result(job)
    local stdout, stderr
    while true do
        if (stdout and stdout[1]) or (stderr and stderr[1]) then
            return {
                stdout = stdout,
                stderr = stderr,
            }
        end
        vim.wait(200, function()
            ---@diagnostic disable-next-line: missing-return,undefined-field
            stdout = job:result()
            ---@diagnostic disable-next-line: missing-return,undefined-field
            stderr = job:stderr_result()
        end)
    end
end

--- Create pull_request_thread descriptive line
--- @param pull_request_thread adopure.Thread
--- @return string
function M.pull_request_thread_title(pull_request_thread)
    return table.concat({
        "[",
        pull_request_thread.id,
        " - ",
        pull_request_thread.status,
        "] ",
        M.format_ado_date(pull_request_thread.lastUpdatedDate or pull_request_thread.publishedDate),
        "  ",
        pull_request_thread.comments[1].content,
    })
end

local hex_to_char = function(x)
    return string.char(tonumber(x, 16))
end

---@param input string
M.url_decode = function(input)
    if input == nil then
        return
    end
    input = input:gsub("+", " ")
    input = input:gsub("%%(%x%x)", hex_to_char)
    return input
end

return M
