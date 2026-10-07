-- Headless bootstrap for running specs with plenary-busted, e.g.:
--   nvim --headless -u tests/minimal_init.lua \
--     -c "PlenaryBustedFile spec/api_spec.lua tests/minimal_init.lua"
-- Prepends the plugin root to the runtimepath so require("adopure.*")
-- resolves; the upstream busted/luarocks setup (see .busted) resolves
-- modules through lpath instead.
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(plugin_root)
