# HANDOFF — pipe game (working name "Aqueduct")

Autonomous `/crunch` build. Resume pointer: `.auto-sprint-board/crunch-state.json`.
Spec: `docs/DESIGN.md` · Backlog: `docs/ROADMAP.md` · Epic plan: `docs/epics/core-model.md`.

## Current state
- Gate: `tools/run-gate.ps1` (headless GUT). Green — 75 tests, 74 pass + 1 quarantined control.
- **E0 ✅ · E1 (core-model) CLOSED ✅ · E2 (rendering) CLOSED ✅ — 2/8 sections `proof-passing`.**
- Model `scripts/model/` (pure, Node-free). View `scripts/view/` (`grid_layout`,`tile`,`board_view`,`hud`) + `scripts/main.gd` (controller) + `scenes/main.tscn`. Autoloads: `Config`, `Settings`.
- Playable, PROVEN build-phase loop: render → tap-to-place (invalid=shake) → HUD (countdown/preview/route) → rotation toggle.
- **[integration] entry = `main.gd` scripted mode** (env `PIPE_TEST`), run HEADLESS via console binary, asserts stdout markers.
- **GOTCHAS:** (1) never name a Node method like a native (`rotate()`→hang); (2) view code: explicit `var x: T =` when assigning from untyped `gs`/`layout` calls; (3) input mapping uses absolute `event.position` vs `layout.origin` (not `to_local`).
- **FINDING (human decision):** shortcut-collapse needs t-junctions (deferred) — MVP score = single-path length.

## Next session
- **S3.2** — `FlowAnimator` (`scripts/view/flow_animator.gd`, Node): Timer drives `gs.step()` +
  `BoardView.refresh()` each tick; checks `gs.outcome_now()`; on terminal/settle stops Timer +
  emits `outcome_resolved(outcome, score)`. `resolve_immediately()` (stops Timer, `gs.resolve()`,
  same emit) for the headless gate. Wire `_start_flow()` to start it.

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
- S2.2 — tap-to-place: `BoardView._unhandled_input`→`cell_tapped`; `Main.place_at` (controller mutates model)→`notify_changed`/shake+buzz; touch-down highlight. Integration: PLACE_OK/BAD + STATE_CHANGED_COUNT=1.
- S2.3 — `hud.gd` (CanvasLayer): countdown + 5-preview + route readout; binds `BoardView.state_changed`; Main countdown tick. Integration: COUNTDOWN/PREVIEW_LEN=5/ROUTE 0→3.
- S2.4 — `Settings` autoload (rotation/audio/haptics) + HUD toggle + Rotate buttons; `Main._effective_rotation` gates rotation. Integration: ROT_OFF=0/ROT_ON=1. (Renamed rotate→cycle_rotation.)
- S2.5 — E2 reflection remediation: absolute tap mapping + hud double-connect guard + input-path test (TAP_CELL=(1,2)).
- E2 close — harden (Tile _DIRS const), regression green, PROOF PASS → rendering-build-input `proof-passing` (2/8).
- E3 plan — flow-outcomes, council-clean (start_flow guard, resolve_immediately stops Timer, animator-loop test).
- S3.1 — model `outcome_now()` public + `score_route()` (BFS path) + GO seam (HUD GO button + countdown-expiry, phase-guarded; placement disabled in FLOW). gate 79; integration PHASE 0→1.
