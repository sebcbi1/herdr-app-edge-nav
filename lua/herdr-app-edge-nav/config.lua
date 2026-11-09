---Options, and the chords read from Herdr.app's keys.json. keys.json stays the
---single source of truth for which keys navigate; nothing is written back.
---@class HerdrAppEdgeNavConfig
local M = {}

local defaults = {
  -- At Neovim's window edge: 'wrap' (default) hands over to the app's edge-nav
  -- mod; 'stop' does nothing; 'split' opens a new Neovim split; or a function
  -- receiving { direction, split, wrap, is_sidebar }.
  at_edge = 'wrap',
  -- Keep the cursor on the same screen row when moving left/right.
  move_cursor_same_row = false,
  -- Windows treated as sidebars (never split by at_edge = 'split').
  ignored_buftypes = { 'nofile', 'quickfix', 'prompt', 'help', 'terminal' },
  ignored_filetypes = {
    'NvimTree',
    'neo-tree',
    'snacks_dashboard',
    'snacks_explorer',
    'snacks_picker',
    'dadbod-ui',
    'dbout',
    'aerial',
    'Outline',
    'Trouble',
    'quickfix',
  },
  -- A floating window with a zindex below this is an embedded sidebar (e.g.
  -- the snacks explorer): it stays put instead of handing over to Herdr.
  floating_zindex_max = 50,
  -- Treat previewwindow windows as sidebars too.
  ignore_previewwindows = false,
  -- Path to herdr-app (auto-detected if nil).
  herdr_app_bin = nil,
}

for k, v in pairs(defaults) do
  M[k] = v
end

---@param opts table|nil
function M.setup(opts)
  if not opts then
    return
  end
  for k, v in pairs(vim.tbl_deep_extend('force', M, opts)) do
    M[k] = v
  end
end

---Herdr.app's keys.json ($HERDR_APP_HOME, else ~/.config/herdr-app).
---@return string
function M.keys_path()
  local home = vim.env.HERDR_APP_HOME
  if not home or home == '' then
    home = (vim.env.HOME or vim.fn.expand('~')) .. '/.config/herdr-app'
  end
  return home .. '/keys.json'
end

---Chords bound to the edge-nav mod's Neovim-aware commands
---(`"ctrl-left": "edge-nav.left"`), in any section.
---@return table<string, string> direction -> chord ("left" -> "ctrl-left")
function M.read_keys()
  local f = io.open(M.keys_path(), 'r')
  if not f then
    return {}
  end
  local text = f:read('*a')
  f:close()
  local ok, data = pcall(vim.json.decode, text)
  if not ok or type(data) ~= 'table' then
    return {}
  end
  local result = {}
  for _, section in pairs(data) do
    if type(section) == 'table' then
      for chord, action in pairs(section) do
        local dir = type(action) == 'string' and action:match('^edge%-nav%.(%a+)$')
        if dir == 'left' or dir == 'right' or dir == 'up' or dir == 'down' then
          result[dir] = chord
        end
      end
    end
  end
  return result
end

local MOD_TO_NVIM = {
  ctrl = 'C', control = 'C',
  shift = 'S',
  alt = 'M', option = 'M', meta = 'M',
  cmd = 'D', command = 'D', super = 'D',
}

local SPECIAL_TO_NVIM = {
  space = 'Space',
  enter = 'CR', ['return'] = 'CR',
  esc = 'Esc', escape = 'Esc',
  tab = 'Tab',
  backspace = 'BS',
  left = 'Left', right = 'Right', up = 'Up', down = 'Down',
  home = 'Home', ['end'] = 'End', pageup = 'PageUp', pagedown = 'PageDown',
}

---Translate a Herdr.app chord ("ctrl-left", "alt-h", "ctrl-shift-k") into
---Neovim keymap notation ("<C-Left>", "<M-h>", "<C-S-k>"). Nil when it can't.
---@param chord string|nil
---@return string|nil
function M.chord_to_nvim(chord)
  if type(chord) ~= 'string' or chord == '' then
    return nil
  end
  -- Split on '-' but keep a trailing '-' key ("cmd--").
  local parts = {}
  for part in chord:gmatch('([^-]+)') do
    parts[#parts + 1] = part
  end
  if chord:sub(-1) == '-' then
    parts[#parts + 1] = '-'
  end
  if #parts == 0 then
    return nil
  end

  local key_token = table.remove(parts)
  local mods = {}
  for _, part in ipairs(parts) do
    local mod = MOD_TO_NVIM[part:lower()]
    if not mod then
      return nil
    end
    mods[#mods + 1] = mod
  end

  local lower = key_token:lower()
  local key, named
  if lower:match('^f%d+$') then
    key, named = lower:upper(), true
  elseif SPECIAL_TO_NVIM[lower] then
    key, named = SPECIAL_TO_NVIM[lower], true
  else
    key, named = key_token, false
  end

  if #mods == 0 then
    return named and ('<' .. key .. '>') or key
  end
  return '<' .. table.concat(mods, '-') .. '-' .. key .. '>'
end

return M
