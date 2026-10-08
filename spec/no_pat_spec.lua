local assert = require("luassert.assert")

describe("no-PAT auth mode", function()
    local curl
    local real_curl_request
    local real_notify
    local notifications
    local captured_requests

    local function reload()
        package.loaded["adopure.api"] = nil
        package.loaded["adopure.config.internal"] = nil
        vim.g.adopure = { organization = "org", project = "proj" }
        return require("adopure.api")
    end

    before_each(function()
        curl = require("plenary.curl")
        real_curl_request = curl.request
        real_notify = vim.notify
        notifications = {}
        captured_requests = {}
        curl.request = function(opts)
            table.insert(captured_requests, vim.deepcopy(opts))
            return { status = 200, body = '{"count":0,"value":[]}' }
        end
        vim.notify = function(message)
            table.insert(notifications, message)
        end
    end)

    after_each(function()
        curl.request = real_curl_request
        vim.notify = real_notify
        vim.g.adopure = nil
    end)

    it("access_token returns nil instead of asserting when no pat is configured", function()
        reload()
        local config = require("adopure.config.internal")
        config.pat_token = nil
        assert.is_nil(config:access_token())
    end)

    it("api module loads without a pat_token configured", function()
        local api = reload()
        require("adopure.config.internal").pat_token = nil
        assert.is_truthy(api)
    end)

    it("sends no Authorization header when no pat is configured", function()
        local api = reload()
        require("adopure.config.internal").pat_token = nil
        api.get_connection_data()
        assert.are.same(1, #captured_requests)
        assert.is_nil(captured_requests[1].headers["Authorization"])
        assert.are.same("application/json", captured_requests[1].headers["Content-Type"])
    end)

    it("sends a basic Authorization header when a pat is configured", function()
        local api = reload()
        require("adopure.config.internal").pat_token = "test-pat"
        api.get_connection_data()
        assert.are.same(
            "basic " .. vim.base64.encode(":test-pat"),
            captured_requests[1].headers["Authorization"]
        )
    end)

    it("notifies once about the missing pat, not on every request", function()
        local api = reload()
        require("adopure.config.internal").pat_token = nil
        api.get_connection_data()
        api.get_connection_data()
        local missing_pat_notices = vim.tbl_filter(function(message)
            return string.find(message, "no pat_token", 1, true) ~= nil
        end, notifications)
        assert.are.same(1, #missing_pat_notices)
    end)
end)
