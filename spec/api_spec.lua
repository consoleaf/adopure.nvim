local assert = require("luassert.assert")

describe("api request plumbing", function()
    local curl
    local real_curl_request
    local real_notify
    local captured_requests
    local canned_response

    local function reload_modules()
        package.loaded["adopure.api"] = nil
        package.loaded["adopure.config.internal"] = nil
        return require("adopure.api")
    end

    local function mock_curl()
        captured_requests = {}
        curl.request = function(opts)
            table.insert(captured_requests, vim.deepcopy(opts))
            return canned_response
        end
    end

    before_each(function()
        curl = require("plenary.curl")
        real_curl_request = curl.request
        real_notify = vim.notify
        canned_response = { status = 200, body = '{"count":0,"value":[]}' }
        vim.g.adopure = { organization = "org", project = "proj" }
    end)

    after_each(function()
        curl.request = real_curl_request
        vim.notify = real_notify
        vim.g.adopure = nil
    end)

    it("loads without a pat_token configured", function()
        local api = reload_modules()
        require("adopure.config.internal").pat_token = nil
        assert.is_truthy(api)
    end)

    it("sends no Authorization header when no pat_token is configured", function()
        local api = reload_modules()
        require("adopure.config.internal").pat_token = nil
        mock_curl()
        local result = api.get_connection_data()
        assert.are.same(1, #captured_requests)
        assert.is_nil(captured_requests[1].headers["Authorization"])
        assert.are.same("application/json", captured_requests[1].headers["Content-Type"])
        assert.is_truthy(result)
    end)

    it("sends a basic Authorization header when a pat_token is configured", function()
        local api = reload_modules()
        require("adopure.config.internal").pat_token = "test-pat"
        mock_curl()
        api.get_connection_data()
        assert.are.same(1, #captured_requests)
        assert.are.same(
            "basic " .. vim.base64.encode(":test-pat"),
            captured_requests[1].headers["Authorization"]
        )
    end)

    it("notifies once about a missing pat_token, not on every request", function()
        local api = reload_modules()
        require("adopure.config.internal").pat_token = nil
        mock_curl()
        local notifications = {}
        vim.notify = function(message)
            table.insert(notifications, message)
        end
        api.get_connection_data()
        api.get_connection_data()
        local missing_pat_notices = vim.tbl_filter(function(message)
            return string.find(message, "no pat_token", 1, true) ~= nil
        end, notifications)
        assert.are.same(1, #missing_pat_notices)
    end)

    it("passes a configured proxy to curl", function()
        local api = reload_modules()
        require("adopure.config.internal").proxy = "http://proxy.example.com:3128"
        mock_curl()
        api.get_connection_data()
        assert.are.same("http://proxy.example.com:3128", captured_requests[1].proxy)
    end)

    it("passes no proxy option to curl when unset or empty", function()
        local api = reload_modules()
        local config = require("adopure.config.internal")
        config.proxy = nil
        mock_curl()
        api.get_connection_data()
        assert.is_nil(captured_requests[1].proxy)

        config.proxy = ""
        api.get_connection_data()
        assert.is_nil(captured_requests[2].proxy)
    end)
end)
