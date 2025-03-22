-- :help notify.Config
local log = require "logger"

local M = {}

M.setup = function(opts)
  print("YAII")
end

M.new_pane = function(cmd)
  local ok, err = pcall(vim.system, cmd, { text = true }, M._new_pane_callback)
  if not ok then
    M.err_notify("Failed to run zellij command:\n" .. err)
  end
  return "expected-output"
end

M._new_pane_callback = function(res)
  log.trace("Zellij._new_pane_callback")

  if res.code == 0 then
    M.ok_notify("SUCCESS")
  else
    M.ok_notify(res.stderr)
  end
end

M.ok_notify = function(msg)
  vim.notify(msg, vim.log.levels.INFO, { title = 'ZELLIJ', timeout = 1000 })
end

M.err_notify = function(msg)
  vim.notify(msg, vim.log.levels.ERROR, { title = 'ZELLIJ', timeout = 1000 })
end

return M
