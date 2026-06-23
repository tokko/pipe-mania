# HANDOFF — pipe game (working name "Aqueduct")

Autonomous `/crunch` build. Resume pointer: `.auto-sprint-board/crunch-state.json`.
Spec: `docs/DESIGN.md` · Backlog: `docs/ROADMAP.md` · Epic plan: `docs/epics/core-model.md`.

## Current state
- Gate: `tools/run-gate.ps1` (headless GUT). Green — 11 tests, 10 pass + 1 quarantined control.
- E0 ✅ scaffold + working gate. **E1 (core-model) in progress.**
- Model lives in `scripts/model/` (pure GDScript, no Node deps; preloaded, no `class_name`).

## Next session
- **S1.2** — seeded `BoardGen` + cell-level solvability BFS (retry ≤ 50, then reduce hazard density).

## History
- E0 — Godot 4.6 project + GUT gate (`667a0e5`).
- E1 plan — channel-aware graph + `FX_CROSS_CORNER` per godot-reviewer (`1879f06`).
- S1.1 — `Board` (cells, inlet/outlet, fixed edge dirs) + `GameState` BUILD→FLOW phase machine.
