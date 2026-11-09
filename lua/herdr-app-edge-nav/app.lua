---Talks to Herdr.app. Edge-crossing belongs to the app's `edge-nav` mod: once
---Neovim is at its own window edge it asks the mod to carry on with
---`herdr-app do edge-nav.cross-<direction>` (pane, then tab/space, then wrap,
---using the mod's options). The `cross-` commands never forward back into
---Neovim, so there is no loop.
---@class HerdrAppEdgeNavApp
local M = {}

local config = require('herdr-app-edge-nav.config')

local KNOWN_PATHS = {
  (vim.env.HOME or '') .. '/.local/bin/herdr-app',
  '/opt/homebrew/bin/herdr-app',
  '/usr/local/bin/herdr-app',
}

---The herdr-app binary, or nil if it isn't installed on this machine.
---@return string|nil
function M.bin()
  if config.herdr_app_bin then
    return config.herdr_app_bin
  end
  local from_path = vim.fn.exepath('herdr-app')
  if from_path ~= '' then
    return from_path
  end
  for _, path in ipairs(KNOWN_PATHS) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
  return nil
end

local detected = nil

---True when this Neovim runs in a terminal Herdr.app shows: a herdr-core
---terminal (HC_TERMINAL_ID) carrying the app's `herdr.space` label, with
---herdr-app installed here. Costs one `hc get`, asked once per session.
---@return boolean
function M.detect()
  if detected ~= nil then
    return detected
  end
  detected = false
  local id = vim.env.HC_TERMINAL_ID
  if not id or id == '' or not M.bin() or vim.fn.executable('hc') ~= 1 then
    return detected
  end
  local ok, obj = pcall(function()
    return vim.system({ 'hc', 'get', id, '--json' }, { text = true }):wait(1000)
  end)
  if not ok or obj.code ~= 0 or not obj.stdout then
    return detected
  end
  local decoded, data = pcall(vim.json.decode, obj.stdout)
  detected = decoded and type(data) == 'table' and type(data.labels) == 'table' and data.labels['herdr.space'] ~= nil
  return detected
end

---Hand the move to the app's edge-nav mod. Asynchronous: Neovim doesn't wait
---for the app to switch panes, tabs or spaces.
---@param direction '"left"'|'"right"'|'"up"'|'"down"'
function M.cross(direction)
  local bin = M.bin()
  if not bin then
    return
  end
  vim.system({ bin, 'do', 'edge-nav.cross-' .. direction }, { text = true }, function(obj)
    if obj.code ~= 0 then
      vim.schedule(function()
        vim.notify(
          ('herdr-app-edge-nav: herdr-app do edge-nav.cross-%s failed: %s%s'):format(
            direction,
            obj.stdout or '',
            obj.stderr or ''
          ),
          vim.log.levels.WARN
        )
      end)
    end
  end)
end

return M
