---herdr-app-edge-nav: the same keys move between Neovim windows and, at
---Neovim's window edge, on through Herdr.app panes, tabs and spaces (via the
---app's edge-nav mod).
---
---No setup() call is required: plugin/herdr-app-edge-nav.lua calls it in any
---herdr-core terminal. setup(opts) stays available to override options.

local config = require('herdr-app-edge-nav.config')
local nav = require('herdr-app-edge-nav.nav')
local app = require('herdr-app-edge-nav.app')

local M = {}

local DIRECTIONS = { 'left', 'down', 'up', 'right' }
local mapped = {}

for _, direction in ipairs(DIRECTIONS) do
  M['move_cursor_' .. direction] = function(opts)
    local ok, err = pcall(nav.move_cursor, direction, opts)
    if not ok then
      vim.notify(('herdr-app-edge-nav: move %s failed: %s'):format(direction, tostring(err)), vim.log.levels.ERROR)
    end
  end
end

---Apply options and map the chords bound to `edge-nav.<direction>` in
---Herdr.app's keys.json. Does nothing outside a terminal Herdr.app shows.
---Safe to call more than once.
---@param opts table|nil
function M.setup(opts)
  config.setup(opts)
  if not app.detect() then
    return
  end

  for _, lhs in ipairs(mapped) do
    pcall(vim.keymap.del, 'n', lhs)
  end
  mapped = {}

  for direction, chord in pairs(config.read_keys()) do
    local lhs = config.chord_to_nvim(chord)
    if lhs then
      vim.keymap.set('n', lhs, M['move_cursor_' .. direction], { desc = 'Navigate ' .. direction .. ' (Herdr.app edge nav)' })
      mapped[#mapped + 1] = lhs
    else
      vim.notify(('herdr-app-edge-nav: cannot map chord %q (edge-nav.%s)'):format(chord, direction), vim.log.levels.WARN)
    end
  end
end

return M
