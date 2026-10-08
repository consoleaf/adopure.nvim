NVIM ?= nvim
INIT := $(CURDIR)/tests/minimal_init.lua

# Offline specs runnable locally without an Azure DevOps PAT or `ado` git
# remote (spec/load_spec.lua and spec/submit_spec.lua are integration tests
# that need real credentials, see .github/workflows/tests.yml).
OFFLINE_SPECS := spec/render_spec.lua

.PHONY: test
test:
	@set -e; for spec in $(OFFLINE_SPECS); do \
		echo "== $$spec"; \
		$(NVIM) --headless -u $(INIT) -c "PlenaryBustedFile $$spec" || exit 1; \
	done; echo "All specs passed"
