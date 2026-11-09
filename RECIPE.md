# Edge Nav

Directional pane navigation that keeps going past the edge of the panes. The person presses `ctrl-left/right/up/down` and focus moves to the neighbouring pane. At the edge of the tab, left/right crosses into the adjacent tab and up/down into the adjacent space, wrapping around at the ends. Inside Neovim, the same keys move between Neovim windows first. There is nothing to see: the mod draws no UI.

## What you see

Nothing new on screen. The mod's single copy is a 0px block docked at the bottom of the layout. The only visible effect is focus moving: between panes, onto another tab (the tab bar's active pill changes), or onto another space (the sidebar's selected space changes).

## How it behaves

- **Not at an edge:** `ctrl-<direction>` focuses the neighbouring pane, exactly like `pane.go`.
- **At an edge, left/right:** selects the previous or next tab of the active space. Settled tabs are skipped unless active. Focus lands on that tab's last focused pane.
- **At an edge, up/down:** selects the previous or next space in `spaces()` order. Remote-machine spaces are included.
- **At the first/last tab or space,** with `WRAP`: selects the last/first one, then walks `pane.go` in the opposite direction until focus stops moving. Focus lands on the pane nearest the side you came from: wrap rightwards and you land on the leftmost pane.
- **One tab or space only,** with `WRAP`: walks to the opposite pane edge of the current tab.
- **`TRAVERSE_TABS` / `TRAVERSE_SPACES` = false:** no crossing on that axis. With `WRAP` it walks to the opposite pane edge; without it, nothing happens.
- **Focused pane runs nvim/vim** (`program.key` is `nvim`, `vim` or `vi`) **and the command is a plain direction:** the bound chord is sent into the terminal with `hc keys <terminal> ctrl+left`, and nothing else happens. The Neovim plugin calls back with `edge-nav.cross-<direction>` at its window edge.
- Agent statuses play no part.

## Built from

- `mods/edge-nav/mod.json`: `{ "place": "bottom", "size": 0, "title": "Edge Nav" }`. On first sight, Herdr wraps the shown layout's root and appends `{ "type": "block", "size": {"px": 0}, "content": {"mod": "edge-nav"} }`.
- `mods/edge-nav/main.js`: a `View` whose `render()` returns `div()`. `init` runs `cx.spawn` with a `for (;;) { await nextCommand() }` loop.
  - Commands: `left|right|up|down` (Neovim-aware) and `cross-left|right|up|down` (never forwarded).
  - Uses `herdr`: `nextCommand`, `focused`, `panes`, `spaces`, `keys`, `hc`, `run`.
  - Commands it runs: `pane.go {direction}`, `tab.select {id}`, `space.select {id}`.
  - `go(direction)`: reads `focused().pane`, runs `pane.go`, then polls `focused().pane` every 4 ms (`cx.sleep(4)`) for up to `SETTLE_MS = 150`. Returns whether it changed.
  - `walkToEdge(direction)`: calls `go()` until it returns false, at most 64 times.
  - After `tab.select`/`space.select`, polls `focused().tab`/`.space` the same way before walking.
  - Options are constants at the top: `TRAVERSE_TABS`, `TRAVERSE_SPACES`, `WRAP` (all `true`).
  - The chord forwarded to Neovim is the `keys()` entry whose action is `edge-nav.<direction>`, with `-` turned into `+` (`ctrl-left` → `ctrl+left`).
- `keys.json`: `global` `ctrl-left/right/up/down` → `edge-nav.left/right/up/down`.
- Runs a program: `hc keys` (herdr-core), only for nvim/vim panes. No network, and no files outside its folder.
- Neovim plugin (same repo): `plugin/herdr-app-edge-nav.lua` calls `setup()` when `HC_TERMINAL_ID` is set. `setup()` checks that `hc get $HC_TERMINAL_ID --json` has a `herdr.space` label and that `herdr-app` is installed. It then maps the `edge-nav.<direction>` chords from the app's `keys.json` (`ctrl-left` → `<C-Left>`) to `move_cursor_<direction>`, which runs `wincmd h/j/k/l`. At Neovim's edge it calls `herdr-app do edge-nav.cross-<direction>` (async `vim.system`).

## Watch out

- **Focus is asynchronous.** `focused()` does not change right after `run("pane.go")`. It usually does within 16 ms. Read it immediately and every move looks like an edge, so poll.
- **Hot reload doesn't end a waiting `nextCommand()` loop.** An earlier build's loop keeps taking commands. In `init`, bump `globalThis.__edgeNavGen`; a loop whose generation is stale re-dispatches the command with `run("edge-nav." + command)` and returns.
- **A symlinked mod folder isn't watched.** Copy it into `mods/`.
- Commands only reach a copy that's in the shown layout. Another layout needs the 0px block added (shipped layouts must be cloned first).
- Test nvims started with the same file names leave swap files behind. The next one stops at the E325 prompt, and `-c` never runs. Use `nvim -n`.
- `tab.new {argv}` launches through `fish -lic 'command …'` (the person's shell), so the foreground process is the shell and the pane doesn't read as nvim. Test Neovim by typing `nvim` into a shell pane.
- There is no pane-resize command in Herdr.app. Don't promise resize.

## Done when

- `herdr-app check ~/.config/herdr-app/mods/edge-nav` passes, and `herdr-app status` shows no errors.
- `herdr-app shot` shows no trace of the mod.
- In a tab split left|right: `herdr-app do edge-nav.right` from the left pane focuses the right pane.
- From the right pane of the last tab, it selects the first tab and lands on its leftmost pane.
- From a single-pane tab, `edge-nav.left` / `right` select the previous / next tab, wrapping at both ends.
- `edge-nav.up` from the top pane of the first space selects the last space; `edge-nav.down` from there returns to the first space's top pane.
- With nvim (`-O a b`) typed into a shell pane: `edge-nav.right` from window 1 moves nvim to window 2 without changing the Herdr pane. The next `edge-nav.right` focuses the Herdr pane to the right.
