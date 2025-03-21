local log = require "logger"

local M = {}

M.setup = function(opts)
  print("YAII")
end

M.new_pane = function(cmd)
  local result = vim.system(cmd, { text = true }, M._new_pane_callback)

  log.trace(vim.inspect(result))
  log.trace(vim.inspect(result))

  return "expected-output"
end

M._new_pane_callback = function(obj)
  log.trace("Zellij._new_pane_callback")

  if obj.code == 0 then
    vim.notify("SUCCESS", vim.log.levels.INFO, {
      title = 'ZELLIJ',
      timeout = 250
    })
  else
    vim.notify(res.stderr, vim.log.levels.ERROR, {
      title = 'ZELLIJ',
      timeout = 250
    })
  end
end

return M
