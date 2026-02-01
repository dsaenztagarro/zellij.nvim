-- =============================================================================
-- ZELLIJ.NVIM TEST SUITE
-- =============================================================================
-- This file contains tests for the zellij.nvim plugin using mini.test.
--
-- LUA CONCEPTS EXPLAINED:
-- -----------------------
-- 1. LOCAL VARIABLES
--    `local x = value` creates a variable scoped to the current block.
--    Unlike global variables, locals are faster and don't pollute the global namespace.
--
-- 2. MULTIPLE ASSIGNMENT
--    `local a, b = table.x, table.y` assigns multiple values in one statement.
--    This is idiomatic Lua for extracting multiple values from a table.
--
-- 3. ANONYMOUS FUNCTIONS
--    `function() ... end` creates an unnamed function (closure).
--    These are commonly used as callbacks or test definitions.
--
-- 4. TABLE AS NAMESPACE
--    `MiniTest.expect` is a table containing functions.
--    Lua uses tables as the foundation for modules, classes, and namespaces.
--
-- 5. METATABLES (used by mini.test internally)
--    Tables can have a "metatable" that defines special behaviors.
--    When you do `T['foo'] = function() end`, mini.test uses metatables
--    to track this as a test case, not just a table field.
-- =============================================================================

-- Import mini.test utilities
-- `new_set()` creates a test set (container for test cases)
-- `expect` contains assertion functions
-- `expect.equality` checks if two values are equal (deep comparison for tables)
local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

-- =============================================================================
-- CHILD NEOVIM PROCESS
-- =============================================================================
-- mini.test's killer feature: run tests in an isolated Neovim instance.
-- This prevents test pollution - each test gets a fresh Neovim state.
--
-- The child process is controlled via RPC (Remote Procedure Call):
-- - `child.lua([[code]])` executes Lua code in the child
-- - `child.lua_get([[expr]])` executes and returns the result
-- - `child.restart()` starts a fresh child process
-- - `child.stop()` terminates the child process
-- =============================================================================
local child = MiniTest.new_child_neovim()

-- =============================================================================
-- TEST SET DEFINITION
-- =============================================================================
-- `new_set()` creates the root test set. It accepts an options table:
--
-- HOOKS EXPLAINED:
-- - `pre_once`: Runs once before ALL tests in this set
-- - `post_once`: Runs once after ALL tests in this set
-- - `pre_case`: Runs before EACH test case
-- - `post_case`: Runs after EACH test case
--
-- This pattern is similar to:
-- - Jest: beforeAll/afterAll/beforeEach/afterEach
-- - RSpec: before(:all)/after(:all)/before(:each)/after(:each)
-- =============================================================================
local T = new_set({
	hooks = {
		-- Before each test: start a fresh child Neovim with our minimal config
		pre_case = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })
			-- Load the zellij module in the child process
			-- The double brackets [[...]] are Lua's long string syntax (no escaping needed)
			child.lua([[Zellij = require('zellij')]])
			-- Set up common mocks for vim.system
			child.lua([[
        _G.captured_cmd = nil
        _G.notifications = {}
        vim.system = function(cmd, opts, callback)
          _G.captured_cmd = cmd
          if callback then
            callback({ code = 0, signal = 0, stdout = '', stderr = '' })
          end
          return {}
        end
        vim.notify = function(msg, level, opts)
          table.insert(_G.notifications, { msg = msg, level = level, opts = opts })
        end
      ]])
		end,
		-- After all tests complete: clean up the child process
		post_once = child.stop,
	},
})

-- =============================================================================
-- NESTED TEST SETS
-- =============================================================================
-- Test sets can be nested for better organization.
-- The string key becomes part of the test name in output.
--
-- SYNTAX: T['name'] = new_set()
-- This creates a sub-group. All tests inside inherit parent hooks.
-- =============================================================================
T["setup()"] = new_set()

-- =============================================================================
-- INDIVIDUAL TEST CASES
-- =============================================================================
-- A test is defined by assigning a function to a string key.
--
-- SYNTAX: T['group']['test name'] = function() ... end
--
-- If the function throws an error, the test fails.
-- If it completes without error, the test passes.
-- =============================================================================
T["setup()"]["returns module table"] = function()
	-- `child.lua_get()` executes Lua in child and returns the result
	-- `type()` is Lua's built-in type checking function
	local result = child.lua_get([[type(Zellij.setup)]])
	eq(result, "function")
end

T["setup()"]["can be called without arguments"] = function()
	-- Using expect.no_error to verify no exception is thrown
	-- The function wrapper is needed because expect.no_error takes a callable
	expect.no_error(function()
		child.lua([[Zellij.setup()]])
	end)
end

-- =============================================================================
-- NEW_PANE TESTS - Basic API
-- =============================================================================
T["new_pane()"] = new_set()

T["new_pane()"]["is a function"] = function()
	local result = child.lua_get([[type(Zellij.new_pane)]])
	eq(result, "function")
end

T["new_pane()"]["handles vim.system errors gracefully"] = function()
	-- Override vim.system to simulate an error
	child.lua([[
    vim.system = function()
      error('Simulated system call failure')
    end
  ]])

	-- Call new_pane - should not throw, should notify
	expect.no_error(function()
		child.lua([[Zellij.new_pane('echo test')]])
	end)

	-- Verify error notification was sent
	local notifications = child.lua_get([[_G.notifications]])
	eq(#notifications, 1)
	eq(notifications[1].level, vim.log.levels.ERROR)
end

T["new_pane()"]["accepts string argument (backwards compatible)"] = function()
	child.lua([[Zellij.new_pane('echo hello')]])

	local cmd = child.lua_get([[_G.captured_cmd]])

	-- Verify base command structure
	eq(cmd[1], "zellij")
	eq(cmd[2], "action")
	eq(cmd[3], "new-pane")
	eq(cmd[4], "--floating") -- Default for string input
	eq(cmd[5], "--")
	-- cmd[6] is the shell (from $SHELL)
	eq(cmd[7], "-c")
	eq(cmd[8], "echo hello")
end

-- =============================================================================
-- NEW_PANE TESTS - Options Table API
-- =============================================================================
T["new_pane() with options"] = new_set()

T["new_pane() with options"]["accepts options table with cmd"] = function()
	child.lua([[Zellij.new_pane({ cmd = 'npm test' })]])

	local cmd = child.lua_get([[_G.captured_cmd]])

	eq(cmd[1], "zellij")
	eq(cmd[2], "action")
	eq(cmd[3], "new-pane")
	eq(cmd[4], "--floating") -- Default is floating
end

T["new_pane() with options"]["respects floating = false"] = function()
	child.lua([[Zellij.new_pane({ cmd = 'npm test', floating = false })]])

	local cmd = child.lua_get([[_G.captured_cmd]])

	-- Should NOT contain --floating
	local has_floating = false
	for _, v in ipairs(cmd) do
		if v == "--floating" then
			has_floating = true
		end
	end
	eq(has_floating, false)
end

T["new_pane() with options"]["respects direction option"] = function()
	child.lua([[Zellij.new_pane({ cmd = 'npm test', floating = false, direction = 'down' })]])

	local cmd = child.lua_get([[_G.captured_cmd]])

	-- Find --direction and its value
	local dir_idx = nil
	for i, v in ipairs(cmd) do
		if v == "--direction" then
			dir_idx = i
		end
	end

	expect.no_equality(dir_idx, nil)
	eq(cmd[dir_idx + 1], "down")
end

T["new_pane() with options"]["respects cwd option"] = function()
	child.lua([[Zellij.new_pane({ cmd = 'ls', cwd = '/tmp' })]])

	local cmd = child.lua_get([[_G.captured_cmd]])

	-- Find --cwd and its value
	local cwd_idx = nil
	for i, v in ipairs(cmd) do
		if v == "--cwd" then
			cwd_idx = i
		end
	end

	expect.no_equality(cwd_idx, nil)
	eq(cmd[cwd_idx + 1], "/tmp")
end

T["new_pane() with options"]["respects name option"] = function()
	child.lua([[Zellij.new_pane({ cmd = 'npm test', name = 'Tests' })]])

	local cmd = child.lua_get([[_G.captured_cmd]])

	-- Find --name and its value
	local name_idx = nil
	for i, v in ipairs(cmd) do
		if v == "--name" then
			name_idx = i
		end
	end

	expect.no_equality(name_idx, nil)
	eq(cmd[name_idx + 1], "Tests")
end

T["new_pane() with options"]["respects close_on_exit option"] = function()
	child.lua([[Zellij.new_pane({ cmd = 'npm test', close_on_exit = true })]])

	local cmd = child.lua_get([[_G.captured_cmd]])

	-- Check for --close-on-exit flag
	local has_close = false
	for _, v in ipairs(cmd) do
		if v == "--close-on-exit" then
			has_close = true
		end
	end
	eq(has_close, true)
end

T["new_pane() with options"]["respects start_suspended option"] = function()
	child.lua([[Zellij.new_pane({ cmd = 'npm test', start_suspended = true })]])

	local cmd = child.lua_get([[_G.captured_cmd]])

	-- Check for --start-suspended flag
	local has_suspended = false
	for _, v in ipairs(cmd) do
		if v == "--start-suspended" then
			has_suspended = true
		end
	end
	eq(has_suspended, true)
end

T["new_pane() with options"]["creates pane without command when cmd is nil"] = function()
	child.lua([[Zellij.new_pane({ floating = true, name = 'Shell' })]])

	local cmd = child.lua_get([[_G.captured_cmd]])

	-- Should have base command and --name, but no -- separator
	eq(cmd[1], "zellij")
	eq(cmd[2], "action")
	eq(cmd[3], "new-pane")

	-- Should NOT contain -- separator (no command to run)
	local has_separator = false
	for _, v in ipairs(cmd) do
		if v == "--" then
			has_separator = true
		end
	end
	eq(has_separator, false)
end

T["new_pane() with options"]["errors on invalid input type"] = function()
	expect.error(function()
		child.lua([[Zellij.new_pane(123)]])
	end)
end

-- =============================================================================
-- NOTIFICATION HELPER TESTS
-- =============================================================================
T["ok_notify()"] = new_set()

T["ok_notify()"]["sends INFO level notification"] = function()
	child.lua([[Zellij.ok_notify('Test message')]])

	local notifications = child.lua_get([[_G.notifications]])
	eq(#notifications, 1)
	eq(notifications[1].msg, "Test message")
	eq(notifications[1].level, vim.log.levels.INFO)
	eq(notifications[1].opts.title, "ZELLIJ")
end

T["err_notify()"] = new_set()

T["err_notify()"]["sends ERROR level notification"] = function()
	child.lua([[Zellij.err_notify('Error message')]])

	local notifications = child.lua_get([[_G.notifications]])
	eq(#notifications, 1)
	eq(notifications[1].msg, "Error message")
	eq(notifications[1].level, vim.log.levels.ERROR)
	eq(notifications[1].opts.title, "Zellij cmd failed")
end

-- =============================================================================
-- CALLBACK TESTS
-- =============================================================================
T["_new_pane_callback()"] = new_set()

T["_new_pane_callback()"]["does not notify on success (code 0)"] = function()
	child.lua([[Zellij._new_pane_callback({ code = 0, stderr = '' })]])

	local notifications = child.lua_get([[_G.notifications]])
	eq(#notifications, 0)
end

T["_new_pane_callback()"]["notifies on error (non-zero code)"] = function()
	child.lua([[Zellij._new_pane_callback({ code = 1, stderr = 'command failed' })]])

	local notifications = child.lua_get([[_G.notifications]])
	eq(#notifications, 1)
	eq(notifications[1].level, vim.log.levels.ERROR)
end

-- =============================================================================
-- RETURN THE TEST SET
-- =============================================================================
-- mini.test expects the test file to return the root test set.
-- This is how it discovers and runs all the tests defined above.
-- =============================================================================
return T
