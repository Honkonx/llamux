.PHONY: install uninstall test lint clean help

PREFIX ?= $(HOME)/.local

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install llamux to PREFIX/bin (default: ~/.local/bin)
	@mkdir -p $(PREFIX)/bin
	@cp -r lib $(PREFIX)/bin/llamux-lib
	@sed 's|$${SCRIPT_DIR}/lib|$(PREFIX)/bin/llamux-lib|g' llamux > $(PREFIX)/bin/llamux || \
		cp llamux $(PREFIX)/bin/llamux
	@chmod +x $(PREFIX)/bin/llamux
	@echo "✅ llamux installed to $(PREFIX)/bin/llamux"
	@echo "   Make sure $(PREFIX)/bin is in your PATH"

uninstall: ## Remove llamux from PREFIX/bin
	@rm -f $(PREFIX)/bin/llamux
	@rm -rf $(PREFIX)/bin/llamux-lib
	@echo "✅ llamux uninstalled"

test: ## Run all tests
	@if command -v bats >/dev/null 2>&1; then \
		bats tests/*.bats; \
	else \
		echo "bats-core not found. Install with: pkg install bats"; \
		exit 1; \
	fi

lint: ## Run ShellCheck on all scripts
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x llamux lib/*.sh && echo "✅ ShellCheck passed"; \
	else \
		echo "shellcheck not found. Install with: pkg install shellcheck"; \
		exit 1; \
	fi

clean: ## Remove build artifacts
	@rm -rf $(HOME)/llamux-build
	@echo "✅ Build artifacts cleaned"