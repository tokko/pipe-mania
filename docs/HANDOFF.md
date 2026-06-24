# HANDOFF — pipe game (working name "Aqueduct")

Autonomous `/crunch` build. Resume pointer: `.auto-sprint-board/crunch-state.json`.
Spec: `docs/DESIGN.md` · Backlog: `docs/ROADMAP.md` · Epic plan: `docs/epics/core-model.md`.

## Current state
- Gate: `tools/run-gate.ps1` (headless GUT). Green — 71 tests, 70 pass + 1 quarantined control.
- E0 ✅ scaffold + gate. **E1 (core-model): all 9 sprints built → entering epic-close.**
- Model in `scripts/model/` (pure GDScript, no Node deps; preloaded, no `class_name`):
  `pipe_types`, `board`, `board_gen`, `piece_queue`, `channel_graph`, `difficulty`, `game_state`.
- `difficulty.config(n)` = pinned ramp (build_seconds/grid/bombs/blocked/weights), capped + monotonic.
- **FINDING:** shortcut-collapse needs branching (t-junctions, deferred) — in MVP score = single-path length ("longer wins"), no shortcut risk yet.

## Next session
- **E1 epic-close** (STEP 6): reflection → harden → regression → proof → retro. The `proof` step
  runs the core-model behavioral proof (headless GUT) asserting every core-model acceptance
  criterion; on pass, mark the section `proof-passing`. Then plan E2 (rendering).

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
