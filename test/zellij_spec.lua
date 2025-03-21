local log = require "logger"
local Zellij = require "zellij"
local Job = require'plenary.job'
local stub = require("luassert.stub")

describe("Zellij", function()
  describe("new_pane", function()
    before_each(function()
      -- stub(vim, "system", function(cmd)
      --   return Job:new({
      --     command = "echo",
      --     args = { "Test Mock Output" },
      --     env = { ['a'] = 'b' },
      --   }):sync()[1]  -- Simulated output
      -- end)

      stub(vim, "system", function(_cmd)
        log.trace("Test.vim.system.callback")
        local response = { code = 0, signal = 0, stdout = "", stderr = "" }
        Zellij._new_pane_callback(response)
        return "SystemCallbackOutput"  -- Directly return a mock string
      end)
    end)

    it("calls vim.system", function()
      log.trace("TEST begins")

      local cmd = {"zellij", "action", "new-pane", "--floating", "--", "zsh", "-c", "HEADFUL=true bundle exec rspec"}

      local notify_stub = stub(vim, "notify")

      local result = Zellij.new_pane(cmd)
      assert.equals(result, "expected-output")  -- Expected output

      assert.stub(notify_stub).was_called_with("SUCCESS", vim.log.levels.INFO, {
        title = 'ZELLIJ',
        timeout = 250
      })
      assert.stub(notify_stub).was_called(1)

      vim.system:revert()
    end)
  end)
end)
