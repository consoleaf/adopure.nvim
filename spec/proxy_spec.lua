local assert = require("luassert.assert")

describe("proxy support", function()
    local curl
    local real_curl_request
    local captured_requests

    local function reload(overrides)
        overrides = overrides or {}
        -- Branch carries proxy support only; the no-PAT mode is a separate
        -- feature. Upstream requires a pat_token at module load, so provide
        -- one unless a test explicitly overrides it.
        overrides.pat_token = overrides.pat_token or "test-pat"
        package.loaded["adopure.api"] = nil
        package.loaded["adopure.config.internal"] = nil
        vim.g.adopure = overrides
        return require("adopure.api")
    end

    before_each(function()
        curl = require("plenary.curl")
        real_curl_request = curl.request
        captured_requests = {}
        curl.request = function(opts)
            table.insert(captured_requests, vim.deepcopy(opts))
            return { status = 200, body = '{"count":0,"value":[]}' }
        end
    end)

    after_each(function()
        curl.request = real_curl_request
        vim.g.adopure = nil
    end)

    it("config defaults proxy to nil", function()
        reload({})
        local config = require("adopure.config.internal")
        assert.is_nil(config.proxy)
    end)

    it("picks up proxy from vim.g.adopure", function()
        reload({ organization = "org", project = "proj", proxy = "http://squid:3128" })
        assert.are.same("http://squid:3128", require("adopure.config.internal").proxy)
    end)

    it("passes the configured proxy to curl", function()
        local api = reload({ organization = "org", project = "proj", proxy = "http://squid:3128" })
        api.get_connection_data()
        assert.are.same(1, #captured_requests)
        assert.are.same("http://squid:3128", captured_requests[1].proxy)
    end)

    it("sends no proxy option when unset or empty", function()
        local api = reload({ organization = "org", project = "proj" })
        api.get_connection_data()
        assert.is_nil(captured_requests[1].proxy)

        require("adopure.config.internal").proxy = ""
        api.get_connection_data()
        assert.is_nil(captured_requests[2].proxy)
    end)

    it("does not alter the Authorization header construction", function()
        local api = reload({ organization = "org", project = "proj", proxy = "http://squid:3128" })
        api.get_connection_data()
        assert.are.same("basic " .. vim.base64.encode(":test-pat"), captured_requests[1].headers["Authorization"])
    end)
end)
