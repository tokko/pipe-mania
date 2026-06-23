# HANDOFF — pipe game (working name "Aqueduct")

Autonomous `/crunch` build. Resume pointer: `.auto-sprint-board/crunch-state.json`.
Spec: `docs/DESIGN.md` · Backlog: `docs/ROADMAP.md` · Epic plan: `docs/epics/core-model.md`.

## Current state
- Gate: `tools/run-gate.ps1` (headless GUT). Green — 54 tests, 53 pass + 1 quarantined control.
- E0 ✅ scaffold + working gate. **E1 (core-model) in progress** (S1.1–S1.5b done).
- Model in `scripts/model/` (pure GDScript, no Node deps; preloaded, no `class_name`).
- Flow `step()` channel-granular; `is_leaking()` detects spilled open edges (off-board + inlet/outlet boundary edges excused). `set_pipe()` builds fixtures.
- Convention: `inlet_dir`/`outlet_dir` = the cell's boundary edge (inlet W, outlet E).

## Next session
- **S1.5c** — bomb-adjacency + clear eval; outlet-reach checked BEFORE bomb (FX_OUTLET_VS_BOMB). Run the godot-reviewer reflection here (full flow-eval picture: step + leak + bomb + clear). Also consider the Phase CLEARED/FAILED state NIT from S1.1.

## History
- E0 — Godot 4.6 project + GUT gate (`667a0e5`).
- E1 plan — channel-aware graph + `FX_CROSS_CORNER` per godot-reviewer (`1879f06`).
- S1.1 — `Board` (cells, inlet/outlet, fixed edge dirs) + `GameState` BUILD→FLOW phase machine.
- S1.2 — seeded `BoardGen` (`scripts/model/board_gen.gd`) + bomb-safe solvability BFS (retry ≤ 50 → reduce density); 200-seed property sweep green.
- S1.3 — `piece_queue.gd` (seeded forced queue + preview) + `PT.piece_edges` orientation model + `GameState` placement (open-only, dry-overwrite, wet-overwrite rejected).
- S1.4 — `channel_graph.gd` channel-aware `(cell,channel)` graph; `cross` = two disjoint channels; corner-cut control green.
- S1.5a — flow `step()` (channel-granular wavefront from inlet seed) + `set_pipe()` fixtures; board_gen inlet/outlet dirs flipped to W/E boundary-edge convention; cross-no-alias control green.
- S1.5b — `is_leaking()` leak eval; off-board + dangling-mouth controls + inlet/outlet-edge-excused positive control.
