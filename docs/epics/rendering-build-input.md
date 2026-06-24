# Epic E2 — Rendering + build-phase input

Implements design section: rendering-build-input. First epic with on-screen, playable output.
The proven pure-logic core (`scripts/model/`, E1) stays the **source of truth and stays
Node-free**; the view OBSERVES it and sends input to it. View code in `scripts/view/` + scenes.

## Design decisions (assumptions — logged for council scrutiny)

- **Model stays pure.** `GameState` gets NO signals/Node deps. The VIEW layer (BoardView/Main)
  emits signals AFTER mutating the model. **Signal contract (council BLOCKER — declared in S2.1
  so S2.3 binds to something fixed):** `BoardView` declares `signal state_changed` and emits it
  after every successful `place()`; the HUD connects to it in S2.3 (no payload — listeners re-read
  the model). Never add engine coupling to `scripts/model/`.
- **Invalid-tap feedback uses public model reads** (no model change): the view checks the public
  `GameState.phase` + `board.cell_at()` to decide shake/buzz when `place()` returns false.
- **Testable view-logic is extracted** so view sprints aren't un-gateable black boxes:
  `scripts/view/grid_layout.gd` (pure RefCounted, **headless GUT**) computes cell pixel size +
  board origin from `(grid_w, grid_h, viewport)`, enforces a **min cell floor** (`MIN_CELL_PX`),
  and maps `cell_to_pixel` / `pixel_to_cell` (round-trip). Rendering/signal wiring are
  `[integration]`/`[screenshot]`-gated.
  - **Floor control must be REAL (council BLOCKER):** at 720×1280 the 9×13 cap gives ~80–98 px
    cells — always ≥44, so a "too-small viewport" control is vacuous there. Exercise the floor
    with a *deliberately small* viewport (e.g. 320×320, big grid) that forces clamp+pan, so the
    failing control can actually go red. (Normal play stays ≥44 dp at the real cap — assert that
    too, as positive liveness.)
- **Tiles pooled at board-load:** `BoardView` instantiates `grid_w*grid_h` `Tile` nodes once,
  positions them via `grid_layout`, and refreshes each from the model — never per-frame churn.
- **Input via signals, not polling:** `BoardView` maps a tap through `grid_layout.pixel_to_cell`
  and emits `cell_tapped(x, y)`; `Main` connects it to `GameState.place(x, y, rotation)`.
- **Deterministic integration entry:** `scripts/main.gd` supports a **scripted test mode**
  (env/arg → load a named fixture board, run a fixed placement sequence, print the cell-state grid
  + route readout to stdout). The `[integration]` gate runs the project **HEADLESS via the console
  binary** (the proven `tools/run-gate.ps1` mechanism — NOT the misconfigured `mcp__godot__` path)
  and asserts the stdout. **Council RISK fix:** `_draw` does not run headless, so the scripted-mode
  asserts MODEL state via prints (no `_draw` dependence); visual `_draw` is a separate
  `[screenshot]` on a *rendered* run. Normal mode = playable.
- **Viewport** 720×1280 portrait (project.godot); `MIN_CELL_PX = 44` (with content-scale ≈ 44 dp);
  board centered in the play area below the HUD.
- **Rotation** comes from a Settings flag (S2.4): default off → fixed spawn rotation; on → the
  view supplies a player-chosen rotation to `place()`.

## Sprint breakdown (TDD where logic allows; view rendering is integration/screenshot-gated)

- **S2.1** [logic+integration] `grid_layout.gd` (headless: cell-floor, cell↔pixel round-trip,
  ≥44dp at the 9×13 cap) + `tile.gd` vector `_draw` (terrain + placed pipe per channel + wet +
  highlight) + `board_view.gd` (pool tiles, render from `GameState`, **declare `signal
  state_changed`**) + `main.tscn`/`main.gd` entry with scripted test mode.
- **S2.2** [integration] tap-to-place: `cell_tapped` signal → `GameState.place`; valid-cell
  highlight on touch-**down**; invalid tap → shake + buzz.
- **S2.3** [integration] HUD (`hud.gd`/`hud.tscn`): build countdown, 5-piece preview, **live
  route-length readout** via `GameState.dry_route_length()`; refresh on `state_changed`.
- **S2.4** [integration] in-run settings icon: rotation toggle (drives `place()` rotation),
  audio, haptics flags (a small `Settings` autoload).

## Test strategy

- **Headless [logic] (GUT):** `grid_layout` — cell↔pixel round-trip is identity; 720×1280 @ 9×13
  yields cell ≥ `MIN_CELL_PX` (positive liveness); **failing control = a small 320×320 viewport
  with a big grid forces clamp+pan below the natural size** (a real red-able assertion). The
  gate-meaningful core.
- **[integration]** via `mcp__godot__run_project` + `get_debug_output`: scripted test mode loads
  `FX_STRAIGHT8`, runs a fixed placement sequence, prints the cell-state grid (assert == fixture
  expected) + the route readout (assert == model `dry_route_length`); countdown decrements;
  rotation toggle changes the exposed-edge mask of a placed piece.
- **[screenshot]** desktop run: board + tiles render, ≥44dp cells, highlight/ shake visible.

## Proof (section: rendering-build-input)

`mcp__godot__run_project` (scripted test mode on a fixture) logs a cell-state grid equal to the
fixture's expected grid, a route readout equal to the model's `dry_route_length`, a decrementing
countdown, and a rotation-toggle effect; plus the `grid_layout` ≥44dp headless test. Real entry
point = `main.tscn`; failing control = the ≥44dp/round-trip controls + a deliberately wrong
expected-grid variant must fail.
