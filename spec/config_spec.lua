local assert = require("luassert.assert")

describe("internal config", function()
    local function new_config(user_config)
        package.loaded["adopure.config.internal"] = nil
        vim.g.adopure = user_config
        return require("adopure.config.internal")
    end

    after_each(function()
        vim.g.adopure = nil
    end)

    it("access_token returns nil when no pat_token is configured", function()
        local config = new_config({})
        config.pat_token = nil
        assert.is_nil(config:access_token())
    end)

    it("access_token encodes the pat_token for basic auth", function()
        local config = new_config({})
        config.pat_token = "test-pat"
        assert.are.same(vim.base64.encode(":test-pat"), config:access_token())
    end)

    it("proxy defaults to nil", function()
        local config = new_config({})
        assert.is_nil(config.proxy)
    end)

    it("picks up user overrides from vim.g.adopure", function()
        local config = new_config({
            pat_token = "from-vim-g",
            proxy = "http://proxy.example.com:3128",
        })
        assert.are.same("from-vim-g", config.pat_token)
        assert.are.same("http://proxy.example.com:3128", config.proxy)
    end)
end)
