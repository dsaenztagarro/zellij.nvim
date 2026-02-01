# =============================================================================
# MAKEFILE FOR ZELLIJ.NVIM
# =============================================================================
# This Makefile provides convenient commands for development and testing.
#
# MAKEFILE CONCEPTS:
# ------------------
# 1. TARGETS
#    Each `target:` line defines a command that can be run with `make target`.
#    The commands below it (indented with TAB) are executed.
#
# 2. .PHONY
#    Tells make that these targets don't represent actual files.
#    Without .PHONY, if a file named 'test' exists, `make test` would skip.
#
# 3. DEPENDENCIES
#    `target: dependency` means dependency must exist/run before target.
#    Example: `test: deps/mini.nvim` ensures mini.nvim is cloned first.
#
# 4. AUTOMATIC VARIABLES
#    $@ = the target name
#    $< = the first dependency
#    $^ = all dependencies
# =============================================================================

.PHONY: all test test-file lint clean help

# Default target when running just `make`
all: test

# =============================================================================
# DEPENDENCIES
# =============================================================================
# Clone mini.nvim for testing framework (mini.test)
# --filter=blob:none does a "blobless clone" - faster, downloads blobs on demand
# =============================================================================
deps/mini.nvim:
	@echo "Cloning mini.nvim for testing..."
	@mkdir -p deps
	@git clone --filter=blob:none https://github.com/echasnovski/mini.nvim deps/mini.nvim

# =============================================================================
# TESTING
# =============================================================================
# Run all tests using mini.test in headless Neovim
#
# FLAGS EXPLAINED:
# --headless    Run without UI (for CI/scripts)
# --noplugin    Don't load user plugins (isolation)
# -u FILE       Use FILE as init script instead of default
# -c "CMD"      Execute CMD after loading
# =============================================================================
test: deps/mini.nvim
	@echo "Running tests..."
	@nvim --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "lua MiniTest.run()"

# Run a specific test file
# Usage: make test-file FILE=tests/test_zellij.lua
test-file: deps/mini.nvim
	@echo "Running $(FILE)..."
	@nvim --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "lua MiniTest.run_file('$(FILE)')"

# =============================================================================
# LINTING
# =============================================================================
# Run code quality checks
# Requires: luacheck, stylua (install via luarocks/cargo)
# =============================================================================
lint:
	@echo "Running luacheck..."
	@luacheck lua/ tests/ --no-unused-args --no-max-line-length || true
	@echo "Checking formatting with stylua..."
	@stylua --check lua/ tests/ || true

# Format code with stylua
format:
	@echo "Formatting with stylua..."
	@stylua lua/ tests/

# =============================================================================
# CLEANUP
# =============================================================================
clean:
	@echo "Cleaning up..."
	@rm -rf deps/

# =============================================================================
# HELP
# =============================================================================
help:
	@echo "Available targets:"
	@echo "  make          - Run all tests (default)"
	@echo "  make test     - Run all tests"
	@echo "  make test-file FILE=path/to/test.lua - Run specific test file"
	@echo "  make lint     - Run linters (luacheck, stylua)"
	@echo "  make format   - Format code with stylua"
	@echo "  make clean    - Remove dependencies"
	@echo "  make help     - Show this help"
