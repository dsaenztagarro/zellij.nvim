-- =============================================================================
-- LUACHECK CONFIGURATION
-- =============================================================================
-- Luacheck is a static analyzer for Lua code.
-- This file configures it for Neovim plugin development.
--
-- LUACHECK CONCEPTS:
-- ------------------
-- 1. GLOBALS
--    Variables that exist without being defined in the file.
--    Neovim injects `vim` globally, and mini.test injects `MiniTest`.
--
-- 2. READ_GLOBALS vs GLOBALS
--    - `read_globals`: Can read but not modify (safer)
--    - `globals`: Can both read and modify
--
-- 3. STD (Standard library)
--    Lua version compatibility. We use luajit for Neovim.
-- =============================================================================

-- Use LuaJIT 5.1 (Neovim's embedded Lua)
std = "luajit"

-- Global variables provided by Neovim
read_globals = {
  "vim",      -- Neovim API (vim.fn, vim.api, vim.opt, etc.)
}

-- Global variables that may be set (test framework)
globals = {
  "MiniTest", -- mini.test testing framework
}

-- Ignore certain warnings
-- 212 = unused argument (common in callbacks)
-- 213 = unused loop variable (common with _ placeholder)
ignore = {
  "212",
  "213",
}

-- Per-file overrides
files = {
  ["tests/**/*.lua"] = {
    -- Tests often define helpers that look unused
    ignore = { "211" }, -- unused local variable
  },
}
