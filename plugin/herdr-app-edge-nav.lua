-- herdr-app-edge-nav bootstrap. Installing the plugin is enough: no setup()
-- call needed. Outside a terminal shown by Herdr.app this is a no-op (no
-- keymaps, no subprocess calls beyond a single `hc get` when HC_TERMINAL_ID
-- is set). Inside one, it maps the chords bound to the edge-nav mod in
-- ~/.config/herdr-app/keys.json.

if vim.g.loaded_herdr_app_edge_nav then
  return
end
vim.g.loaded_herdr_app_edge_nav = true

if vim.env.HC_TERMINAL_ID and vim.env.HC_TERMINAL_ID ~= '' then
  require('herdr-app-edge-nav').setup()
end
