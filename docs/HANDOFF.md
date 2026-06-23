# HANDOFF — pipe game (working name "Aqueduct")

Autonomous `/crunch` build. Resume pointer: `.auto-sprint-board/crunch-state.json`.
Spec: `docs/DESIGN.md` · Backlog: `docs/ROADMAP.md` · Epic plan: `docs/epics/core-model.md`.

## Current state
- Gate: `tools/run-gate.ps1` (headless GUT). Green — 20 tests, 19 pass + 1 quarantined control.
- E0 ✅ scaffold + working gate. **E1 (core-model) in progress** (S1.1, S1.2 done).
- Model lives in `scripts/model/` (pure GDScript, no Node deps; preloaded, no `class_name`).

## Next session
- **S1.3** — seeded piece queue (forced top, 5-preview) + piece/orientation model + placement & dry-pipe overwrite. NOTE: piece-type enum must reserve 0 = NONE (terrain-array contract).

## History
- E0 — Godot 4.6 project + GUT gate (`667a0e5`).
- E1 plan — channel-aware graph + `FX_CROSS_CORNER` per godot-reviewer (`1879f06`).
- S1.1 — `Board` (cells, inlet/outlet, fixed edge dirs) + `GameState` BUILD→FLOW phase machine.
- S1.2 — seeded `BoardGen` (`scripts/model/board_gen.gd`) + bomb-safe solvability BFS (retry ≤ 50 → reduce density); 200-seed property sweep green.
