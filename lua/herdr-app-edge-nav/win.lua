---Neovim window helpers for edge navigation.
---@class HerdrAppEdgeNavWin
local M = {}

local config = require('herdr-app-edge-nav.config')

---@param winid number|nil
---@return boolean
function M.is_ignored_win(winid)
  local bufnr = vim.api.nvim_win_get_buf(winid or 0)
  return vim.tbl_contains(config.ignored_buftypes, vim.api.nvim_get_option_value('buftype', { buf = bufnr }))
    or vim.tbl_contains(config.ignored_filetypes, vim.api.nvim_get_option_value('filetype', { buf = bufnr }))
end

---@param winid number|nil
---@return boolean
function M.is_floating(winid)
  return vim.api.nvim_win_get_config(winid or 0).relative ~= ''
end

---A floating window that behaves like a sidebar (e.g. the snacks explorer):
---Neovim's default floating zindex is 50; one set below that is meant to sit
---alongside normal splits.
---@param winid number|nil
---@return boolean
function M.is_embedded_floating_window(winid)
  if not M.is_floating(winid) then
    return false
  end
  local cfg = vim.api.nvim_win_get_config(winid or 0)
  return cfg.zindex ~= nil and cfg.zindex < (config.floating_zindex_max or 50)
end

---@param winid number|nil
---@return boolean
function M.is_sidebar(winid)
  if M.is_ignored_win(winid) or M.is_embedded_floating_window(winid) then
    return true
  end
  if config.ignore_previewwindows then
    local ok, pw = pcall(vim.api.nvim_get_option_value, 'previewwindow', { win = winid or 0 })
    return ok and pw == true
  end
  return false
end

---True while the command-line window (q:, q/, q?) is open: every window
---command raises E11 there.
---@return boolean
function M.is_command_line_window()
  return vim.fn.getcmdwintype() ~= ''
end

M.dir_keys = { left = 'h', right = 'l', up = 'k', down = 'j' }
M.dir_keys_reverse = { left = 'l', right = 'h', up = 'j', down = 'k' }

return M
