-- :help notify.Config
local log = require "logger"

local M = {}

M.setup = function(opts)
  print("YAII")
end

---@param shell_cmd string[]: the shell command with arguments
M.new_pane = function(shell_cmd)
  local cmd = {"zellij", "action", "new-pane", "--floating", "--", "zsh", "-c", shell_cmd}
  -- log.trace(vim.inspect(cmd))
  local ok, err = pcall(vim.system, cmd, { text = true }, M._new_pane_callback)
  if not ok then
    -- M.err_notify("Failed to run zellij command:\n" .. err)
    log.trace("ERROR " .. err)
    -- err.tostring
    vim.notify("" .. err, vim.log.levels.ERROR, { title = 'Zellij action failed' })
  end
end

M._new_pane_callback = function(res)
  log.trace("Zellij._new_pane_callback")

  if res.code == 0 then
    -- M.ok_notify("SUCCESS")
  else
    M.err_notify(res.stderr .. " " .. res.code)
  end
end

M.ok_notify = function(msg)
  vim.notify(msg, vim.log.levels.INFO, { title = 'ZELLIJ', timeout = 1000 })
end

M.err_notify = function(msg)
  vim.notify(msg, vim.log.levels.ERROR, { title = 'Zellij cmd failed', timeout = 1000 })
end

return M
