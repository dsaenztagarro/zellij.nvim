-- =============================================================================
-- ZELLIJ.NVIM - Neovim Integration for Zellij Terminal Multiplexer
-- =============================================================================
-- This plugin provides seamless integration between Neovim and Zellij,
-- allowing you to control Zellij panes directly from Neovim.
--
-- LUA CONCEPTS EXPLAINED:
-- -----------------------
-- 1. TYPE ANNOTATIONS (`---@`)
--    Lua is dynamically typed, but we use LuaLS (Lua Language Server)
--    annotations for documentation and IDE support.
--    - `---@class` defines a type structure
--    - `---@field` defines a field in a class
--    - `---@param` documents function parameters
--    - `---@return` documents return values
--
-- 2. OPTIONAL FIELDS (`?` suffix)
--    `---@field name? string` means the field is optional (can be nil).
--    This maps to Lua's dynamic nature where table fields can be absent.
--
-- 3. UNION TYPES (`|`)
--    `string|table` means the value can be either type.
--    Useful for flexible APIs like new_pane(cmd) vs new_pane({opts}).
-- =============================================================================

local log = require("logger")

-- =============================================================================
-- TYPE DEFINITIONS
-- =============================================================================
-- These annotations create a schema that editors can use for autocomplete
-- and type checking. They don't affect runtime behavior.
-- =============================================================================

---@class ZellijNewPaneOpts
---Options table for creating a new Zellij pane.
---All fields are optional; sensible defaults are applied.
---
---@field cmd? string Shell command to execute in the pane
---@field floating? boolean Open as floating pane (default: true)
---@field direction? "right"|"down" Direction for tiled pane (ignored if floating)
---@field cwd? string Working directory for the pane
---@field name? string Name to assign to the pane
---@field close_on_exit? boolean Close pane when command exits (default: false)
---@field start_suspended? boolean Wait for keypress before running (default: false)

-- =============================================================================
-- MODULE TABLE
-- =============================================================================
-- The module pattern: we create an empty table `M` and add all public
-- functions to it. At the end, we `return M` to export the module.
--
-- This is Lua's standard way of creating modules/namespaces.
-- When users call `require('zellij')`, they get this table.
-- =============================================================================

---@class Zellij
---@field setup fun(opts?: table): nil Configure the plugin
---@field new_pane fun(opts: string|ZellijNewPaneOpts): nil Create a new pane
local M = {}

-- =============================================================================
-- PRIVATE HELPER FUNCTIONS
-- =============================================================================
-- Functions starting with underscore are conventionally "private" in Lua.
-- This is just a naming convention - Lua has no access modifiers.
--
-- LUA PATTERN: Local functions
-- Defining functions with `local function name()` instead of `M.name`
-- means they're not accessible from outside the module. This is true privacy.
-- =============================================================================

---Build the command array for vim.system() from options
---
---LUA PATTERN: Table building
---We construct the command incrementally using table.insert().
---This is cleaner than concatenating strings and handles arguments properly.
---
---@param opts ZellijNewPaneOpts Options for the new pane
---@return string[] Array of command parts for vim.system()
local function build_new_pane_command(opts)
	-- Start with the base command
	-- Using array literal {...} to create a list
	local cmd = { "zellij", "action", "new-pane" }

	-- Add flags based on options
	-- The pattern `if opts.x then` checks if the value is truthy (not nil/false)

	if opts.floating then
		table.insert(cmd, "--floating")
	elseif opts.direction then
		-- table.insert(tbl, val) appends val to tbl
		table.insert(cmd, "--direction")
		table.insert(cmd, opts.direction)
	end

	if opts.cwd then
		table.insert(cmd, "--cwd")
		table.insert(cmd, opts.cwd)
	end

	if opts.name then
		table.insert(cmd, "--name")
		table.insert(cmd, opts.name)
	end

	if opts.close_on_exit then
		table.insert(cmd, "--close-on-exit")
	end

	if opts.start_suspended then
		table.insert(cmd, "--start-suspended")
	end

	-- Add the actual command to run (if provided)
	-- The `--` separator tells zellij that everything after is the command
	if opts.cmd then
		table.insert(cmd, "--")
		-- We use the user's shell from environment, defaulting to sh
		-- os.getenv() reads environment variables
		local shell = os.getenv("SHELL") or "/bin/sh"
		table.insert(cmd, shell)
		table.insert(cmd, "-c")
		table.insert(cmd, opts.cmd)
	end

	return cmd
end

---Normalize user input into a consistent options table
---
---LUA PATTERN: Function overloading via type checking
---Lua doesn't have function overloading, so we check argument type at runtime.
---This allows `new_pane('cmd')` and `new_pane({cmd='cmd'})` to both work.
---
---@param input string|ZellijNewPaneOpts User-provided input
---@return ZellijNewPaneOpts Normalized options table
local function normalize_options(input)
	-- type(val) returns a string: "nil", "number", "string", "table", etc.
	if type(input) == "string" then
		-- Convert string to options table for backwards compatibility
		return {
			cmd = input,
			floating = true, -- Default to floating for simple commands
		}
	elseif type(input) == "table" then
		-- Apply defaults using the `or` pattern
		-- `a or b` returns `a` if truthy, else `b` (like ?? in other languages)
		-- Note: `false or true` returns `true`, so explicit false is preserved
		return {
			cmd = input.cmd,
			floating = input.floating ~= false, -- Default true unless explicitly false
			direction = input.direction,
			cwd = input.cwd,
			name = input.name,
			close_on_exit = input.close_on_exit or false,
			start_suspended = input.start_suspended or false,
		}
	else
		-- Provide a helpful error message for invalid input
		error("new_pane expects a string or options table, got " .. type(input))
	end
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

---Configure the zellij.nvim plugin
---
---@param opts? table Configuration options (currently unused, reserved for future)
M.setup = function(opts)
	-- Placeholder for future configuration
	-- Will be expanded to support default options, keymaps, etc.
	log.trace("Zellij.setup called", opts)
end

---Create a new Zellij pane
---
---Can be called with a simple string command or an options table:
---
---```lua
----- Simple usage (backwards compatible)
---Zellij.new_pane('echo hello')
---
----- Full options
---Zellij.new_pane({
---  cmd = 'npm test',
---  floating = true,
---  name = 'Tests',
---  close_on_exit = true,
---})
---```
---
---@param opts string|ZellijNewPaneOpts Command string or options table
M.new_pane = function(opts)
	-- Normalize input to options table
	local options = normalize_options(opts)

	-- Build the command array
	local cmd = build_new_pane_command(options)

	log.trace("Zellij.new_pane command:", cmd)

	-- Execute the command asynchronously
	-- pcall(fn, args) calls fn(args) and catches any errors
	-- Returns: (success_bool, result_or_error)
	local ok, err = pcall(vim.system, cmd, { text = true }, M._new_pane_callback)

	if not ok then
		-- err contains the error message when pcall fails
		log.trace("ERROR " .. err)
		vim.notify("" .. err, vim.log.levels.ERROR, { title = "Zellij action failed" })
	end
end

---Internal callback for handling vim.system() completion
---
---LUA PATTERN: Callback convention
---Callbacks receive a result table from the async operation.
---We prefix with underscore to indicate internal use.
---
---@param res {code: number, signal: number, stdout: string, stderr: string}
M._new_pane_callback = function(res)
	log.trace("Zellij._new_pane_callback", res)

	-- Exit code 0 means success in Unix convention
	-- Non-zero exit code means failure
	if res.code ~= 0 then
		M.err_notify(res.stderr .. " " .. res.code)
	end
	-- Success is silent by default (can be configured later)
end

---Display a success notification
---
---@param msg string Message to display
M.ok_notify = function(msg)
	vim.notify(msg, vim.log.levels.INFO, { title = "ZELLIJ", timeout = 1000 })
end

---Display an error notification
---
---@param msg string Error message to display
M.err_notify = function(msg)
	vim.notify(msg, vim.log.levels.ERROR, { title = "Zellij cmd failed", timeout = 1000 })
end

return M
