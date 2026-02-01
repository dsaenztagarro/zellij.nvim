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
-- NEW_PANE TESTS
-- =============================================================================
T["new_pane()"] = new_set()

T["new_pane()"]["is a function"] = function()
	local result = child.lua_get([[type(Zellij.new_pane)]])
	eq(result, "function")
end

T["new_pane()"]["handles vim.system errors gracefully"] = function()
	-- Override vim.system to simulate an error
	-- This tests the pcall error handling in new_pane
	child.lua([[
    -- Store original for potential restoration
    _G.original_vim_system = vim.system

    -- Replace with error-throwing mock
    vim.system = function()
      error('Simulated system call failure')
    end

    -- Track notifications
    _G.notifications = {}
    vim.notify = function(msg, level, opts)
      table.insert(_G.notifications, {
        msg = msg,
        level = level,
        opts = opts
      })
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

T["new_pane()"]["calls vim.system with correct command structure"] = function()
	-- Mock vim.system to capture the command
	child.lua([[
    _G.captured_cmd = nil
    vim.system = function(cmd, opts, callback)
      _G.captured_cmd = cmd
      -- Simulate successful async response
      if callback then
        callback({ code = 0, signal = 0, stdout = '', stderr = '' })
      end
      return {}
    end
  ]])

	child.lua([[Zellij.new_pane('echo hello')]])

	local cmd = child.lua_get([[_G.captured_cmd]])

	-- Verify command structure
	eq(cmd[1], "zellij")
	eq(cmd[2], "action")
	eq(cmd[3], "new-pane")
	eq(cmd[4], "--floating")
	eq(cmd[5], "--")
	eq(cmd[6], "zsh")
	eq(cmd[7], "-c")
	eq(cmd[8], "echo hello")
end

-- =============================================================================
-- NOTIFICATION HELPER TESTS
-- =============================================================================
T["ok_notify()"] = new_set()

T["ok_notify()"]["sends INFO level notification"] = function()
	child.lua([[
    _G.last_notification = nil
    vim.notify = function(msg, level, opts)
      _G.last_notification = { msg = msg, level = level, opts = opts }
    end
  ]])

	child.lua([[Zellij.ok_notify('Test message')]])

	local notif = child.lua_get([[_G.last_notification]])
	eq(notif.msg, "Test message")
	eq(notif.level, vim.log.levels.INFO)
	eq(notif.opts.title, "ZELLIJ")
end

T["err_notify()"] = new_set()

T["err_notify()"]["sends ERROR level notification"] = function()
	child.lua([[
    _G.last_notification = nil
    vim.notify = function(msg, level, opts)
      _G.last_notification = { msg = msg, level = level, opts = opts }
    end
  ]])

	child.lua([[Zellij.err_notify('Error message')]])

	local notif = child.lua_get([[_G.last_notification]])
	eq(notif.msg, "Error message")
	eq(notif.level, vim.log.levels.ERROR)
	eq(notif.opts.title, "Zellij cmd failed")
end

-- =============================================================================
-- CALLBACK TESTS
-- =============================================================================
T["_new_pane_callback()"] = new_set()

T["_new_pane_callback()"]["does not notify on success (code 0)"] = function()
	child.lua([[
    _G.notification_count = 0
    vim.notify = function()
      _G.notification_count = _G.notification_count + 1
    end
  ]])

	child.lua([[Zellij._new_pane_callback({ code = 0, stderr = '' })]])

	local count = child.lua_get([[_G.notification_count]])
	eq(count, 0)
end

T["_new_pane_callback()"]["notifies on error (non-zero code)"] = function()
	child.lua([[
    _G.notification_count = 0
    _G.last_notification = nil
    vim.notify = function(msg, level, opts)
      _G.notification_count = _G.notification_count + 1
      _G.last_notification = { msg = msg, level = level }
    end
  ]])

	child.lua([[Zellij._new_pane_callback({ code = 1, stderr = 'command failed' })]])

	local count = child.lua_get([[_G.notification_count]])
	eq(count, 1)

	local notif = child.lua_get([[_G.last_notification]])
	eq(notif.level, vim.log.levels.ERROR)
end

-- =============================================================================
-- RETURN THE TEST SET
-- =============================================================================
-- mini.test expects the test file to return the root test set.
-- This is how it discovers and runs all the tests defined above.
-- =============================================================================
return T
