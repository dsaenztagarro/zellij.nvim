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
--
-- 4. DEEP TABLE MERGING
--    `vim.tbl_deep_extend('force', defaults, user_opts)` recursively merges
--    tables. 'force' means user values override defaults.
--    This is essential for configuration systems with nested options.
-- =============================================================================

local log = require("logger")

-- =============================================================================
-- TYPE DEFINITIONS
-- =============================================================================
-- These annotations create a schema that editors can use for autocomplete
-- and type checking. They don't affect runtime behavior.
-- =============================================================================

---@class ZellijPaneDefaults
---Default settings for new panes.
---@field floating boolean Whether panes are floating by default (default: true)
---@field close_on_exit boolean Close pane when command exits (default: false)
---@field start_suspended boolean Wait for keypress before running (default: false)

---@class ZellijNotificationConfig
---Configuration for notification behavior.
---@field enabled boolean Whether notifications are enabled at all (default: true)
---@field on_success boolean Show notification on successful commands (default: false)
---@field on_error boolean Show notification on errors (default: true)

---@class ZellijConfig
---Main configuration table for zellij.nvim.
---All fields are optional and have sensible defaults.
---
---@field shell? string Shell to use for commands (default: $SHELL or /bin/sh)
---@field defaults? ZellijPaneDefaults Default pane settings
---@field notifications? ZellijNotificationConfig Notification settings

---@class ZellijNewPaneOpts
---Options table for creating a new Zellij pane.
---All fields are optional; sensible defaults are applied.
---
---@field cmd? string Shell command to execute in the pane
---@field floating? boolean Open as floating pane (uses config default if nil)
---@field direction? "right"|"down" Direction for tiled pane (ignored if floating)
---@field cwd? string Working directory for the pane
---@field name? string Name to assign to the pane
---@field close_on_exit? boolean Close pane when command exits (uses config default if nil)
---@field start_suspended? boolean Wait for keypress before running (uses config default if nil)

---@class ZellijRunOpts
---Options for the run() convenience function.
---Same as ZellijNewPaneOpts but without cmd (it's the first argument).
---
---@field floating? boolean Open as floating pane (uses config default if nil)
---@field direction? "right"|"down" Direction for tiled pane (ignored if floating)
---@field cwd? string Working directory for the pane
---@field name? string Name to assign to the pane
---@field close_on_exit? boolean Close pane when command exits (uses config default if nil)
---@field start_suspended? boolean Wait for keypress before running (uses config default if nil)

---@class ZellijEditOpts
---Options for the edit() function.
---Controls how the file is opened in a new pane.
---
---@field floating? boolean Open as floating pane (uses config default if nil)
---@field direction? "right"|"down" Direction for tiled pane (ignored if floating)
---@field line? number Line number to jump to (uses +line syntax)
---@field cwd? string Working directory for the editor

-- =============================================================================
-- DEFAULT CONFIGURATION
-- =============================================================================
-- LUA PATTERN: Configuration defaults
-- We define defaults as a local table, then merge user config on top.
-- This pattern ensures all config keys have valid values even if
-- the user only provides partial configuration.
-- =============================================================================

---@type ZellijConfig
local DEFAULT_CONFIG = {
	-- Shell defaults to environment variable, with fallback
	shell = nil, -- Will use os.getenv("SHELL") or "/bin/sh" at runtime

	-- Default pane behavior
	defaults = {
		floating = true,
		close_on_exit = false,
		start_suspended = false,
	},

	-- Notification preferences
	notifications = {
		enabled = true,
		on_success = false, -- Silent success by default
		on_error = true, -- Show errors by default
	},
}

-- =============================================================================
-- MODULE STATE
-- =============================================================================
-- LUA PATTERN: Module-level state
-- Variables declared with `local` at module level persist across function calls
-- but are private to the module. This is how we store configuration.
--
-- IMPORTANT: This is "module state" - it's shared across all uses of the module.
-- In Neovim, `require('zellij')` returns the same cached module table,
-- so this config persists for the entire Neovim session.
-- =============================================================================

---@type ZellijConfig
local config = vim.deepcopy(DEFAULT_CONFIG)

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
---@field setup fun(opts?: ZellijConfig): nil Configure the plugin
---@field new_pane fun(opts: string|ZellijNewPaneOpts): nil Create a new pane
---@field run fun(cmd: string, opts?: ZellijRunOpts): nil Run command in new pane (convenience alias)
---@field edit fun(file: string, opts?: ZellijEditOpts): nil Open file in new pane with $EDITOR
---@field get_config fun(): ZellijConfig Get current configuration (for testing)
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

---Get the shell to use for commands
---
---@return string The shell path
local function get_shell()
	-- Priority: config.shell > $SHELL > /bin/sh
	return config.shell or os.getenv("SHELL") or "/bin/sh"
end

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
		table.insert(cmd, get_shell())
		table.insert(cmd, "-c")
		table.insert(cmd, opts.cmd)
	end

	return cmd
end

---Build the command array for zellij action edit
---
---LUA PATTERN: Separate command builders
---We keep build functions separate for each action type.
---This makes the code easier to test and modify independently.
---
---@param file string Path to the file to edit
---@param opts ZellijEditOpts Options for the edit command
---@return string[] Array of command parts for vim.system()
local function build_edit_command(file, opts)
	local cmd = { "zellij", "action", "edit" }

	if opts.floating then
		table.insert(cmd, "--floating")
	elseif opts.direction then
		table.insert(cmd, "--direction")
		table.insert(cmd, opts.direction)
	end

	if opts.cwd then
		table.insert(cmd, "--cwd")
		table.insert(cmd, opts.cwd)
	end

	-- Line number support: zellij edit uses --line flag
	if opts.line then
		table.insert(cmd, "--line-number")
		table.insert(cmd, tostring(opts.line))
	end

	-- The file path is the last argument
	table.insert(cmd, file)

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
	-- Get defaults from config
	local defaults = config.defaults

	-- type(val) returns a string: "nil", "number", "string", "table", etc.
	if type(input) == "string" then
		-- Convert string to options table for backwards compatibility
		-- Use config defaults for behavior
		return {
			cmd = input,
			floating = defaults.floating,
			close_on_exit = defaults.close_on_exit,
			start_suspended = defaults.start_suspended,
		}
	elseif type(input) == "table" then
		-- Apply config defaults for unspecified options
		-- LUA PATTERN: Nil-coalescing with config fallback
		-- `input.x == nil and defaults.x or input.x` handles both nil and false correctly
		return {
			cmd = input.cmd,
			-- For booleans, we need special handling because `false or true` returns `true`
			-- We use explicit nil check: if user didn't specify, use default
			floating = input.floating == nil and defaults.floating or input.floating,
			direction = input.direction,
			cwd = input.cwd,
			name = input.name,
			close_on_exit = input.close_on_exit == nil and defaults.close_on_exit or input.close_on_exit,
			start_suspended = input.start_suspended == nil and defaults.start_suspended or input.start_suspended,
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
---Call this in your Neovim config to customize behavior:
---
---```lua
---require('zellij').setup({
---  shell = '/bin/zsh',
---  defaults = {
---    floating = true,
---    close_on_exit = true,
---  },
---  notifications = {
---    on_success = true,  -- Show success messages
---    on_error = true,
---  },
---})
---```
---
---@param opts? ZellijConfig Configuration options
M.setup = function(opts)
	-- LUA PATTERN: Deep merge configuration
	-- vim.tbl_deep_extend('force', a, b) merges b into a, with b taking priority
	-- 'force' means when keys conflict, the later table wins
	-- We use vim.deepcopy to avoid mutating DEFAULT_CONFIG
	if opts then
		config = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULT_CONFIG), opts)
	else
		config = vim.deepcopy(DEFAULT_CONFIG)
	end

	log.trace("Zellij.setup called with config:", config)
end

---Get the current configuration (useful for testing and debugging)
---
---@return ZellijConfig Current configuration
M.get_config = function()
	return config
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
		if config.notifications.enabled and config.notifications.on_error then
			vim.notify("" .. err, vim.log.levels.ERROR, { title = "Zellij action failed" })
		end
	end
end

---Run a command in a new Zellij pane (convenience alias for new_pane)
---
---LUA PATTERN: Convenience wrappers
---This is a thin wrapper that provides a more intuitive API for the common
---use case of running a command. Instead of `new_pane({cmd='...', ...})`,
---users can write `run('...', {...})`.
---
---```lua
----- Simple usage
---Zellij.run('npm test')
---
----- With options
---Zellij.run('cargo build', { close_on_exit = true, name = 'Build' })
---```
---
---@param cmd string The command to run
---@param opts? ZellijRunOpts Optional settings for the pane
M.run = function(cmd, opts)
	-- LUA PATTERN: Table merging for function arguments
	-- We create a new table that combines the command with any provided options.
	-- vim.tbl_extend('force', {}, opts or {}) safely handles nil opts.
	local pane_opts = vim.tbl_extend("force", opts or {}, { cmd = cmd })
	M.new_pane(pane_opts)
end

---Open a file in a new Zellij pane using the system editor ($EDITOR)
---
---This leverages Zellij's built-in edit action, which opens files using
---the EDITOR environment variable. Useful for:
--- - Side-by-side editing of related files
--- - Viewing log files while editing code
--- - Opening the current buffer in a separate pane
---
---```lua
----- Open a file
---Zellij.edit('/path/to/file.lua')
---
----- Open current buffer's file in a floating pane
---Zellij.edit(vim.fn.expand('%:p'), { floating = true })
---
----- Open at specific line (useful for error jumping)
---Zellij.edit('/path/to/file.lua', { line = 42 })
---```
---
---@param file string Path to the file to edit (use vim.fn.expand for current buffer)
---@param opts? ZellijEditOpts Optional settings for the pane
M.edit = function(file, opts)
	-- Apply defaults for edit options
	-- LUA PATTERN: Nil-safe option access with defaults
	-- We use the same pattern as normalize_options for boolean handling:
	-- `x == nil and default or x` correctly handles false values
	opts = opts or {}
	local defaults = config.defaults
	local edit_opts = {
		floating = opts.floating == nil and defaults.floating or opts.floating,
		direction = opts.direction,
		line = opts.line,
		cwd = opts.cwd,
	}

	-- Build the command array
	local cmd = build_edit_command(file, edit_opts)

	log.trace("Zellij.edit command:", cmd)

	-- Execute the command asynchronously
	local ok, err = pcall(vim.system, cmd, { text = true }, M._new_pane_callback)

	if not ok then
		log.trace("ERROR " .. err)
		if config.notifications.enabled and config.notifications.on_error then
			vim.notify("" .. err, vim.log.levels.ERROR, { title = "Zellij edit failed" })
		end
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
	if res.code == 0 then
		-- Success notification (if enabled)
		if config.notifications.enabled and config.notifications.on_success then
			M.ok_notify("Command completed successfully")
		end
	else
		-- Non-zero exit code means failure
		if config.notifications.enabled and config.notifications.on_error then
			M.err_notify(res.stderr .. " " .. res.code)
		end
	end
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
