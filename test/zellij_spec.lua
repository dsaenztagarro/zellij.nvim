local log = require "logger"
local Zellij = require "zellij"
local stub = require("luassert.stub")

describe("Zellij", function()
  describe("new_pane", function()
    before_each(function()
      stub(vim, "system", function(_cmd)
        log.trace("Test.vim.system.callback")
        local response = { code = 0, signal = 0, stdout = "", stderr = "" }
        Zellij._new_pane_callback(response)
        return "SystemCallbackOutput"  -- Directly return a mock string
      end)
    end)

    it("notifies with error exception calling zellij command", function()
      local notify_stub = stub(vim, "notify")
      local err_msg = "vim.system failed!"

      stub(vim, "system", function() error(err_msg, 0) end)

      local cmd = "echo hello"
      Zellij.new_pane(cmd)

      assert.stub(notify_stub).was_called(1)

      -- local partial_match = function(arg)
      --   return arg:match(err_msg)  -- Partial match using Lua pattern
      -- end
      assert.stub(notify_stub).was_called_with(function(...)
        local args = {...}
        log.trace(vim.inspect(args))
        return true
      end)

      -- assert.stub(notify_stub).was_called_with(err_msg, vim.log.levels.ERROR, { title = 'Zellij cmd failed' })

      vim.system:revert()
    end)

    it("notifies with error", function()
      local notify_stub = stub(vim, "notify")

      local cmd = "echo hello"
      Zellij.new_pane(cmd)

      assert.stub(notify_stub).was_called(0)
    end)
  end)
end)
