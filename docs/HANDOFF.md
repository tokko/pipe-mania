# HANDOFF — pipe game (working name "Aqueduct")

Autonomous `/crunch` build. Resume pointer: `.auto-sprint-board/crunch-state.json`.
Spec: `docs/DESIGN.md` · Backlog: `docs/ROADMAP.md` · Epic plan: `docs/epics/core-model.md`.

## Current state
- Gate: `tools/run-gate.ps1` (headless GUT). Green — 34 tests, 33 pass + 1 quarantined control.
- E0 ✅ scaffold + working gate. **E1 (core-model) in progress** (S1.1–S1.3 done).
- Model lives in `scripts/model/` (pure GDScript, no Node deps; preloaded, no `class_name`).

## Next session
- **S1.4** — channel-aware `(cell, channel)` connection graph; `cross` = two disjoint nodes so no traversal corner-cuts. This is the BLOCKER-fix sprint; run the godot-reviewer reflection.

## History
- E0 — Godot 4.6 project + GUT gate (`667a0e5`).
- E1 plan — channel-aware graph + `FX_CROSS_CORNER` per godot-reviewer (`1879f06`).
- S1.1 — `Board` (cells, inlet/outlet, fixed edge dirs) + `GameState` BUILD→FLOW phase machine.
- S1.2 — seeded `BoardGen` (`scripts/model/board_gen.gd`) + bomb-safe solvability BFS (retry ≤ 50 → reduce density); 200-seed property sweep green.
- S1.3 — `piece_queue.gd` (seeded forced queue + preview) + `PT.piece_edges` orientation model + `GameState` placement (open-only, dry-overwrite, wet-overwrite rejected).
