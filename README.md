# Edge Nav for Herdr.app

A [Herdr.app](https://herdr.dev) mod for directional pane navigation that keeps going past the edge of the panes:

- **Left/right** at the edge of a tab's panes crosses into the adjacent **tab** of the space.
- **Up/down** at the edge crosses into the adjacent **space**.
- At the first/last tab or space it **wraps around** and lands on the pane nearest the side you came from.
- **Neovim-aware** (optional): the same keys move between Neovim splits first and only reach Herdr at Neovim's own window edge.

This is the Herdr.app port of the TUI plugin [herdr-edge-nav](https://github.com/sebcbi1/herdr-edge-nav): TUI workspaces are Herdr.app spaces. The repo holds both the mod and its Neovim plugin.

## Install

```sh
cp -R mods/edge-nav ~/.config/herdr-app/mods/
```

Copy the folder rather than symlinking it: Herdr.app does not hot-reload a symlinked mod folder.

Then merge `keys.json` into `~/.config/herdr-app/keys.json`. It replaces the default `ctrl-left/right/up/down → pane.go:*` bindings:

```json
{ "global": { "ctrl-left": "edge-nav.left", "ctrl-right": "edge-nav.right",
              "ctrl-up": "edge-nav.up", "ctrl-down": "edge-nav.down" } }
```

Any chord works. Bind it to `edge-nav.<direction>`.

The mod draws nothing. The first time Herdr sees it, it docks one invisible copy (`size 0`) into the layout that's showing. That copy is what receives the key commands. If you use **another layout**, add the block there too, anywhere in the tree (a personal layout, or a clone of a shipped one):

```json
{ "id": "edge-nav", "type": "block", "size": { "px": 0 }, "content": { "mod": "edge-nav" } }
```

Check it with `herdr-app check ~/.config/herdr-app/mods/edge-nav`.

## Options

Constants at the top of `mods/edge-nav/main.js`:

| Option | Default | Meaning |
|---|---|---|
| `TRAVERSE_TABS` | `true` | left/right at an edge crosses into the adjacent tab |
| `TRAVERSE_SPACES` | `true` | up/down at an edge crosses into the adjacent space |
| `WRAP` | `true` | wrap to the first/last tab or space; when traversal is off, wrap to the opposite pane edge |

## Commands

| Command | What it does |
|---|---|
| `edge-nav.left` / `right` / `up` / `down` | The move. In an nvim/vim pane, the bound chord is forwarded into the editor instead. |
| `edge-nav.cross-left` / `…` | The same move, never forwarded. This is what Neovim calls at its own edge. |

You can also run these from a shell: `herdr-app do edge-nav.right`.

## Neovim integration

This repo is also a Neovim plugin (`lua/herdr-app-edge-nav/`, `plugin/herdr-app-edge-nav.lua`; Neovim >= 0.10). Install it and you're done, with no `setup()` call:

```lua
-- vim.pack (Neovim >= 0.12)
vim.pack.add({ { src = 'https://github.com/sebcbi1/herdr-app-edge-nav', name = 'herdr-app-edge-nav' } })

-- lazy.nvim
{ 'sebcbi1/herdr-app-edge-nav', event = 'VeryLazy' }
```

In a terminal Herdr.app shows (a herdr-core terminal with the app's `herdr.space` label, and `herdr-app` installed), the plugin:

1. maps the chords bound to `edge-nav.*` in `~/.config/herdr-app/keys.json` (or `$HERDR_APP_HOME`), e.g. `ctrl-left` → `<C-Left>`;
2. moves between Neovim windows first (counts work: `3<C-Left>`);
3. at Neovim's window edge, runs `herdr-app do edge-nav.cross-<direction>`. The mod then continues with the pane, tab or space move, or the wrap.

```text
ctrl-left in a pane running nvim
  └─ edge-nav mod: focused program is nvim → hc keys <terminal> ctrl+left
       └─ nvim plugin: a window to the left? → move inside nvim
                       at nvim's edge?      → herdr-app do edge-nav.cross-left
                                                └─ mod: pane / tab / space / wrap
```

Anywhere else it does nothing: no keymaps. The only cost is one `hc get` when `HC_TERMINAL_ID` is set.

Optional overrides, through `require('herdr-app-edge-nav').setup(opts)`:

| Option | Default | Meaning |
|---|---|---|
| `at_edge` | `'wrap'` | at Neovim's edge: `'wrap'` hands over to Herdr.app, `'stop'` does nothing, `'split'` opens a split, or `function(ctx)` (`ctx.direction`, `ctx.split()`, `ctx.wrap()`, `ctx.is_sidebar`) |
| `move_cursor_same_row` | `false` | keep the cursor's screen row when moving left/right |
| `ignored_filetypes` / `ignored_buftypes` | sidebars (neo-tree, snacks, aerial, Trouble, quickfix, …) | treated as sidebars: never split by `'split'` |
| `floating_zindex_max` | `50` | floats below this zindex are embedded sidebars and stay put; other floats hand over to Herdr.app |
| `ignore_previewwindows` | `false` | treat preview windows as sidebars |
| `herdr_app_bin` | auto | path to `herdr-app` |

It can be installed next to the TUI plugin [herdr-edge-nav](https://github.com/sebcbi1/herdr-edge-nav). Its modules and load guard have their own names. Each plugin only acts in its own app: the TUI plugin when `HERDR_ENV=1`, this one in Herdr.app.

## Limits

- **No resize.** Herdr.app has no pane-resize command, so the TUI plugin's `resize-*` actions have no equivalent here. Neovim resize keymaps are not set up in Herdr.app.
- Edge detection works by trying `pane.go` and checking whether focus moved, since Herdr.app has no edges API. At an edge, the mod waits up to 150 ms (`SETTLE_MS`) before crossing.
- `pane.go` also reaches visible mods that declare `"focusable": true`, so such a panel counts as a neighbour.
- Settled tabs are skipped, like `tab.next`.
- Neovim resize isn't mapped. The Neovim callback runs `herdr-app` on the machine Neovim runs on. Neovim inside a terminal on a remote machine falls back to plain Neovim window navigation.
- When crossing without a wrap, focus lands on the target tab's or space's last focused pane (same as the TUI plugin).

## Files

- `mods/edge-nav/main.js`: the mod.
- `mods/edge-nav/mod.json`: `{"place": "bottom", "size": 0}`, which docks the invisible copy.
- `keys.json`: the bindings it expects.
- `lua/herdr-app-edge-nav/`, `plugin/herdr-app-edge-nav.lua`: the Neovim plugin (`app.lua` detects Herdr.app and calls the mod, `config.lua` holds the options and reads keys.json, `nav.lua` moves between windows, `win.lua` has the window helpers, `init.lua` holds setup and the keymaps).
- `RECIPE.md`: the brief for rebuilding it from scratch.

## License

MIT
