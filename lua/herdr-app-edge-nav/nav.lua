---Move between Neovim windows; at Neovim's window edge, hand over to Herdr.app.
---@class HerdrAppEdgeNavNav
local M = {}

local config = require('herdr-app-edge-nav.config')
local app = require('herdr-app-edge-nav.app')
local win = require('herdr-app-edge-nav.win')

local function split_edge(direction)
  vim.cmd((direction == 'left' or direction == 'right') and 'vsplit' or 'split')
end

---@param direction '"left"'|'"right"'|'"up"'|'"down"'
---@param opts table|nil { same_row: boolean|nil, at_edge: string|function|nil }
function M.move_cursor(direction, opts)
  opts = type(opts) == 'table' and opts or {}
  local same_row = opts.same_row
  if same_row == nil then
    same_row = config.move_cursor_same_row
  end
  local at_edge = opts.at_edge
  if at_edge == nil then
    at_edge = config.at_edge
  end

  -- Floating windows go straight to Herdr, except embedded sidebars, which
  -- stay put.
  if win.is_floating() then
    if not win.is_embedded_floating_window() then
      app.cross(direction)
    end
    return
  end

  local dir_key = win.dir_keys[direction]
  local count = vim.v.count1
  local at_nvim_edge
  if count > 1 then
    at_nvim_edge = vim.fn.winnr(count .. dir_key) == vim.fn.winnr((count - 1) .. dir_key)
  else
    at_nvim_edge = vim.fn.winnr(dir_key) == vim.fn.winnr()
  end

  -- Command-line window: window commands raise E11, only handing over is safe.
  if win.is_command_line_window() then
    if at_nvim_edge and count == 1 then
      app.cross(direction)
    end
    return
  end

  local row = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
  local prev_win = vim.api.nvim_get_current_win()
  vim.cmd(count .. 'wincmd ' .. dir_key)

  if vim.api.nvim_get_current_win() ~= prev_win then
    if same_row and (direction == 'left' or direction == 'right') then
      local target = row - vim.api.nvim_win_get_position(0)[1]
      if target > 0 then
        vim.cmd('normal! ' .. target .. 'H')
      end
    end
    return
  end

  -- At Neovim's window edge. A count that ran out of windows stops here.
  if not (at_nvim_edge and count == 1) then
    return
  end

  if type(at_edge) == 'function' then
    at_edge({
      direction = direction,
      is_sidebar = win.is_sidebar(),
      split = function() split_edge(direction) end,
      wrap = function() vim.cmd('wincmd ' .. win.dir_keys_reverse[direction]) end,
    })
  elseif at_edge == 'stop' then
    return
  elseif at_edge == 'split' then
    if not win.is_sidebar() then
      split_edge(direction)
    end
  else -- 'wrap': the edge-nav mod moves on (pane, tab/space, wrap)
    app.cross(direction)
  end
end

return M
