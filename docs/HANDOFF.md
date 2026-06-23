# HANDOFF — pipe game (working name "Aqueduct")

Autonomous `/crunch` build. Resume pointer: `.auto-sprint-board/crunch-state.json`.
Spec: `docs/DESIGN.md` · Backlog: `docs/ROADMAP.md` · Epic plan: `docs/epics/core-model.md`.

## Current state
- Gate: `tools/run-gate.ps1` (headless GUT). Green — 66 tests, 65 pass + 1 quarantined control.
- E0 ✅ scaffold + working gate. **E1 (core-model) in progress** (S1.1–S1.6 done; only S1.7 left).
- Model in `scripts/model/` (pure GDScript, no Node deps; preloaded, no `class_name`).
- `score()` = shortest wet inlet→outlet route (cells); `dry_route_length()` for the build readout. Cross-corner scores 0 (no BFS corner-cut).
- **FINDING:** shortcut-collapse needs branching (t-junctions, deferred). In MVP every route is a unique linear path, so score = path length, "longer wins", no shortcut risk yet. BFS impl already handles shortcuts when t-junctions land.

## Next session
- **S1.7** — `DifficultyConfig(n)` per the pinned table in docs/ROADMAP.md (build_seconds, grid_w/h, bombs, blocked, piece weights). Assert exact values at n=0/5/15 + monotonicity. Last E1 sprint → then epic-close.

## History
- E0 — Godot 4.6 project + GUT gate (`667a0e5`).
- E1 plan — channel-aware graph + `FX_CROSS_CORNER` per godot-reviewer (`1879f06`).
- S1.1 — `Board` (cells, inlet/outlet, fixed edge dirs) + `GameState` BUILD→FLOW phase machine.
- S1.2 — seeded `BoardGen` (`scripts/model/board_gen.gd`) + bomb-safe solvability BFS (retry ≤ 50 → reduce density); 200-seed property sweep green.
- S1.3 — `piece_queue.gd` (seeded forced queue + preview) + `PT.piece_edges` orientation model + `GameState` placement (open-only, dry-overwrite, wet-overwrite rejected).
- S1.4 — `channel_graph.gd` channel-aware `(cell,channel)` graph; `cross` = two disjoint channels; corner-cut control green.
- S1.5a — flow `step()` (channel-granular wavefront from inlet seed) + `set_pipe()` fixtures; board_gen inlet/outlet dirs flipped to W/E boundary-edge convention; cross-no-alias control green.
- S1.5b — `is_leaking()` leak eval; off-board + dangling-mouth controls + inlet/outlet-edge-excused positive control.
- S1.5c — `Outcome` enum + `resolve()` (CLEARED>BOMB>LEAK per ring) + `is_cleared`/`is_bombed`; FX_OUTLET_VS_BOMB control green.
- S1.6 — `score()`/`dry_route_length()` shortest-route BFS; straight-8→8, winding→7, cross-corner→0 vs bend-control→3, unconnected→0.
