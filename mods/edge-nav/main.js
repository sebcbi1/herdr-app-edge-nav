// edge-nav: directional pane navigation that crosses into the adjacent tab
// (left/right) or space (up/down) at a pane edge, with optional wrap-around.
// Port of the herdr-edge-nav TUI plugin (github.com/sebcbi1/herdr-edge-nav).
//
// Keys (keys.json): "ctrl-left": "edge-nav.left", ... (also right/up/down).
// Commands:
//   left|right|up|down              Neovim-aware: in an nvim/vim pane the bound
//                                   chord is forwarded into the editor instead.
//   cross-left|right|up|down        Same move, never forwarded: what the Neovim
//                                   plugin calls at its own window edge.
//
// It draws nothing: the copy only exists so key commands have somewhere to go.

import { View, div } from "gpui-kit";
import { nextCommand, focused, run, panes, spaces, keys, hc } from "herdr";

// Options.
const TRAVERSE_TABS = true;   // left/right at an edge crosses into the adjacent tab
const TRAVERSE_SPACES = true; // up/down at an edge crosses into the adjacent space
const WRAP = true;            // wrap to the first/last tab or space (or the opposite pane edge)

// pane.go applies a moment after run() returns: wait this long for focus to
// move before deciding the pane was already at the edge.
const SETTLE_MS = 150;
const MAX_WALK = 64;

const DIRECTIONS = ["left", "right", "up", "down"];
const OPPOSITE = { left: "right", right: "left", up: "down", down: "up" };
const OFFSET = { left: -1, up: -1, right: 1, down: 1 };
const VIM = new Set(["nvim", "vim", "vi"]);

const focusedPane = () => focused()?.pane ?? null;

// Focuses the neighbour in `direction`; resolves true if focus moved.
async function go(direction, cx) {
  const before = focusedPane();
  run("pane.go", { direction });
  const until = Date.now() + SETTLE_MS;
  while (focusedPane() === before && Date.now() < until) await cx.sleep(4);
  return focusedPane() !== before;
}

// Keeps going in `direction` until there is no neighbour left: lands on the
// extreme pane on that side.
async function walkToEdge(direction, cx) {
  for (let i = 0; i < MAX_WALK && (await go(direction, cx)); i++);
}

// Waits until the shown tab/space is `id` (selection also applies async).
async function settleOn(read, id, cx) {
  const until = Date.now() + SETTLE_MS;
  while (read() !== id && Date.now() < until) await cx.sleep(4);
}

// The chord bound to edge-nav.<direction> ("ctrl-left"), as hc spells it ("ctrl+left").
function boundChord(direction) {
  const b = keys().find((k) => k.action === `edge-nav.${direction}`);
  return (b?.keys ?? `ctrl-${direction}`).replace(/-(?=.)/g, "+");
}

async function nav(direction, vimAware, cx) {
  const pane = panes().find((p) => p.focused);

  if (vimAware && pane?.terminal && VIM.has(pane.program?.key)) {
    await hc(["keys", pane.terminal, boundChord(direction)]);
    return;
  }

  if (await go(direction, cx)) return;

  const horizontal = direction === "left" || direction === "right";
  const opposite = OPPOSITE[direction];

  if (!(horizontal ? TRAVERSE_TABS : TRAVERSE_SPACES)) {
    if (WRAP) await walkToEdge(opposite, cx);
    return;
  }

  const space = spaces().find((s) => s.active);
  const list = horizontal ? (space?.tabs ?? []).filter((t) => !t.settled || t.active) : spaces();
  const current = list.findIndex((x) => x.active);
  if (current < 0 || list.length < 2) {
    if (WRAP) await walkToEdge(opposite, cx);
    return;
  }

  let next = current + OFFSET[direction];
  const wrapped = next < 0 || next >= list.length;
  if (wrapped) {
    if (!WRAP) return;
    next = (next + list.length) % list.length;
  }

  const target = list[next].id;
  if (horizontal) {
    run("tab.select", { id: target });
    await settleOn(() => focused()?.tab, target, cx);
  } else {
    run("space.select", { id: target });
    await settleOn(() => focused()?.space, target, cx);
  }

  // After a wrap, land on the pane nearest the side we came from.
  if (wrapped) await walkToEdge(opposite, cx);
}

export default class EdgeNav extends View {
  init(_props, cx) {
    // A hot reload can leave an earlier build's loop waiting on nextCommand();
    // the newest copy claims the generation, and a superseded loop hands any
    // command it still receives back so the current build handles it.
    const gen = (globalThis.__edgeNavGen = (globalThis.__edgeNavGen ?? 0) + 1);
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        if (globalThis.__edgeNavGen !== gen) {
          run(`edge-nav.${command}`);
          return;
        }
        const cross = command.startsWith("cross-");
        const direction = cross ? command.slice(6) : command;
        if (!DIRECTIONS.includes(direction)) continue;
        try {
          await nav(direction, !cross, cx);
        } catch (e) {
          console.log(`[edge-nav] ${command} failed: ${e}`);
        }
      }
    });
  }

  render() {
    return div();
  }
}
