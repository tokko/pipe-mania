# HANDOFF — pipe game (working name "Aqueduct")

Autonomous `/crunch` build. Resume pointer: `.auto-sprint-board/crunch-state.json`.
Spec: `docs/DESIGN.md` · Backlog: `docs/ROADMAP.md` · Epic plan: `docs/epics/core-model.md`.

## Current state
- Gate: `tools/run-gate.ps1` (headless GUT). Green — 75 tests, 74 pass + 1 quarantined control.
- E0 ✅ · **E1 (core-model) CLOSED — `proof-passing` (1/8).** · **E2 (rendering) in progress** (S2.1 done).
- Model in `scripts/model/` (pure, Node-free). **View in `scripts/view/`** (`grid_layout`, `tile`, `board_view`) + `scripts/main.gd` + `scenes/main.tscn` (run/main_scene).
- View observes the model; `BoardView` declares `cell_tapped` + `state_changed`. `main.gd` scripted mode (env `PIPE_TEST`) is the headless [integration] entry.
- **Integration check (S2.1):** `PIPE_TEST=1` headless run → TILES=5, CELL_SIZE=144, DRY_ROUTE=5, SAMPLE_20=1.
- **FINDING (human decision):** shortcut-collapse needs t-junctions (deferred) — MVP score = single-path length.
- **Process note:** reviewer agents time out on broad scope; use tight, output-bounded reviews.

## Next session
- **S2.2** — tap-to-place: `BoardView._unhandled_input` → `grid_layout.pixel_to_cell` → emit
  `cell_tapped` → `GameState.place(x,y,rotation)` → emit `state_changed` + `refresh()`; valid-cell
  highlight on touch-down; invalid tap (place() false) → shake + buzz, using public `phase`/`cell_at`.

## History
- E0 — Godot 4.6 project + GUT gate (`667a0e5`).
- E1 plan — channel-aware graph + `FX_CROSS_CORNER` per godot-reviewer (`1879f06`).
- S1.1 — `Board` + `GameState` BUILD→FLOW phase machine.
- S1.2 — seeded `BoardGen` + bomb-safe solvability BFS (retry ≤ 50 → reduce density); 200-seed sweep.
- S1.3 — `piece_queue.gd` forced queue + `PT.piece_edges` orientation + placement (dry/wet overwrite rules).
- S1.4 — `channel_graph.gd` channel-aware `(cell,channel)` graph; `cross` = two disjoint channels; corner-cut control.
- S1.5a — flow `step()` (channel-granular wavefront) + `set_pipe()` fixtures; inlet/outlet W/E boundary convention.
- S1.5b — `is_leaking()` leak eval; off-board + dangling-mouth controls.
- S1.5c — `Outcome` + `resolve()` (CLEARED>BOMB>LEAK per ring); FX_OUTLET_VS_BOMB control.
- S1.6 — `score()`/`dry_route_length()` shortest-route BFS; cross-corner→0 vs bend-control→3.
- S1.7 — `difficulty.config(n)` pinned ramp table; exact n=0/5/15 + monotonicity + caps.
- E2 plan — rendering epic plan, council-clean (real ≥44dp control, state_changed contract, headless integration).
- S2.1 — `grid_layout` (headless: round-trip + floor control) + `tile`/`board_view` (pooled render) + `main` scripted entry + `main.tscn`; integration green.
