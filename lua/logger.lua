-- =============================================================================
-- LOGGER MODULE
-- =============================================================================
-- A simple logging utility for the zellij.nvim plugin.
-- This replaces the plenary.log dependency with a self-contained solution.
--
-- LUA CONCEPTS EXPLAINED:
-- -----------------------
-- 1. MODULE PATTERN
--    Lua doesn't have built-in classes or modules. We use tables as modules:
--    - Create an empty table `local M = {}`
--    - Add functions to it `M.func = function() end`
--    - Return it at the end `return M`
--
-- 2. CLOSURE
--    A function that "captures" variables from its enclosing scope.
--    Here, `log_level` is captured by all the logging functions.
--
-- 3. VARARGS (`...`)
--    The `...` syntax captures any number of arguments.
--    `{...}` packs them into a table.
--    `select('#', ...)` returns the count of varargs.
--
-- 4. STRING FORMATTING
--    `string.format(fmt, ...)` works like printf in C.
--    `vim.inspect(val)` converts any Lua value to a readable string.
-- =============================================================================

local M = {}

-- =============================================================================
-- LOG LEVELS
-- =============================================================================
-- Using numbers allows comparison: if current_level >= TRACE then log
-- This pattern is common in logging frameworks (log4j, Python logging, etc.)
-- =============================================================================
M.levels = {
	TRACE = 1,
	DEBUG = 2,
	INFO = 3,
	WARN = 4,
	ERROR = 5,
	OFF = 6,
}

-- Current log level - only messages at this level or higher are logged
-- Default to OFF in production to avoid performance overhead
local log_level = M.levels.OFF

-- =============================================================================
-- HELPER: FORMAT MESSAGE
-- =============================================================================
-- Converts multiple arguments into a single string for logging.
--
-- LUA PATTERN: Table manipulation with ipairs
-- `ipairs(tbl)` iterates over array-like tables in order (1, 2, 3, ...)
-- It returns (index, value) pairs and stops at the first nil.
-- =============================================================================
local function format_message(...)
	local args = { ... }
	local parts = {}
	for i, arg in ipairs(args) do
		if type(arg) == "string" then
			parts[i] = arg
		else
			-- vim.inspect converts tables, functions, etc. to readable strings
			parts[i] = vim.inspect(arg)
		end
	end
	return table.concat(parts, " ")
end

-- =============================================================================
-- HELPER: LOG MESSAGE
-- =============================================================================
-- Internal function that does the actual logging.
--
-- LUA PATTERN: Higher-order functions
-- This is called by trace(), debug(), etc. with different level values.
-- =============================================================================
local function log(level, level_name, ...)
	if level < log_level then
		return
	end

	local msg = format_message(...)
	local timestamp = os.date("%H:%M:%S")

	-- Print to Neovim's message area (visible with :messages)
	-- Using vim.schedule to avoid issues when called from async contexts
	vim.schedule(function()
		print(string.format("[%s][%s] %s", timestamp, level_name, msg))
	end)
end

-- =============================================================================
-- PUBLIC API: LOGGING FUNCTIONS
-- =============================================================================
-- Each level has its own function for convenience.
--
-- LUA PATTERN: Forwarding varargs
-- When you write `function(...) other_func(...) end`, all arguments
-- are forwarded to the inner function. This is called "vararg forwarding".
-- =============================================================================

---Log a trace-level message (most verbose)
---@param ... any Arguments to log (will be converted to strings)
function M.trace(...)
	log(M.levels.TRACE, "TRACE", ...)
end

---Log a debug-level message
---@param ... any Arguments to log
function M.debug(...)
	log(M.levels.DEBUG, "DEBUG", ...)
end

---Log an info-level message
---@param ... any Arguments to log
function M.info(...)
	log(M.levels.INFO, "INFO", ...)
end

---Log a warning-level message
---@param ... any Arguments to log
function M.warn(...)
	log(M.levels.WARN, "WARN", ...)
end

---Log an error-level message (most severe)
---@param ... any Arguments to log
function M.error(...)
	log(M.levels.ERROR, "ERROR", ...)
end

-- =============================================================================
-- PUBLIC API: CONFIGURATION
-- =============================================================================

---Set the minimum log level
---@param level number One of M.levels (TRACE, DEBUG, INFO, WARN, ERROR, OFF)
function M.set_level(level)
	log_level = level
end

---Get the current log level
---@return number The current log level
function M.get_level()
	return log_level
end

return M
