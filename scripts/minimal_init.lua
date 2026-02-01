-- =============================================================================
-- MINIMAL INIT SCRIPT FOR TESTING
-- =============================================================================
-- This script sets up a minimal Neovim environment for running tests.
-- It's used with `nvim --headless -u scripts/minimal_init.lua` to create
-- an isolated test environment.
--
-- LUA CONCEPTS EXPLAINED:
-- -----------------------
-- 1. `vim.fn.fnamemodify()` - Neovim's Vimscript function wrapper
--    - `fnamemodify(path, ':h')` gets the "head" (directory) of a path
--    - `:h:h` applied twice goes up two directory levels
--
-- 2. `vim.opt.rtp:prepend()` - Runtime path manipulation
--    - `vim.opt.rtp` is a Neovim option wrapper (not raw table)
--    - `:prepend()` adds to the beginning of the path list
--    - This is equivalent to `set rtp^=path` in Vimscript
--
-- 3. `debug.getinfo(1, 'S').source:sub(2)` - Get current script path
--    - `debug.getinfo(1, 'S')` gets info about current function (level 1)
--    - `.source` contains the file path prefixed with '@'
--    - `:sub(2)` removes the '@' prefix (substring from position 2)
-- =============================================================================

-- Get the directory where this script lives, then go up one level to project root
local this_file = debug.getinfo(1, "S").source:sub(2)
local project_root = vim.fn.fnamemodify(this_file, ":h:h")

-- Add the project root to runtime path so `require('zellij')` works
-- The :prepend() method adds to the BEGINNING of rtp, giving it priority
vim.opt.rtp:prepend(project_root)

-- Add mini.nvim to runtime path for mini.test functionality
-- We expect mini.nvim to be cloned into deps/mini.nvim
local mini_path = project_root .. "/deps/mini.nvim"
vim.opt.rtp:prepend(mini_path)

-- =============================================================================
-- MINI.TEST SETUP
-- =============================================================================
-- `require('mini.test').setup()` initializes the testing framework with:
-- - Test discovery (finds test_*.lua files in tests/)
-- - Reporter configuration (how results are displayed)
-- - Hook management (pre/post test callbacks)
-- =============================================================================
require("mini.test").setup()
