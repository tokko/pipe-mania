# HANDOFF — pipe game (working name "Aqueduct")

Autonomous `/crunch` build. Resume pointer: `.auto-sprint-board/crunch-state.json`.
Spec: `docs/DESIGN.md` · Backlog: `docs/ROADMAP.md` · Epic plan: `docs/epics/core-model.md`.

## Current state
- Gate: `tools/run-gate.ps1` (headless GUT). Green — 89 tests, 88 pass + 1 quarantined control.
- **E0 ✅ · E1 ✅ · E2 ✅ · E3 ✅ · E4 (endless-run) CLOSED ✅ — 4/8 sections `proof-passing`.** Remaining: E5 difficulty-onboarding, E6 juice, E7a android-export, E7b stubbed-services.
- Model `scripts/model/` (pure, Node-free). View `scripts/view/` (`grid_layout`,`tile`,`board_view`,`flow_animator`,`hud`) + `scripts/main.gd` (controller) + `scenes/main.tscn`. Autoloads: `Config`, `Settings`.
- Full endless loop: build → GO/expiry → `FlowAnimator` runs water → CLEARED banks score + advances to next (harder) board via `Run`/`_mount_board`; LEAK/BOMB → run-end + `SaveStore` high-score + Restart. HUD shows run/best score.
- **[integration] entry = `main.gd` scripted mode** (env `PIPE_TEST`), run HEADLESS via console binary, asserts stdout markers.
- **GOTCHAS:** (1) never name a Node method like a native (`rotate()`→hang); (2) view code: explicit `var x: T =` when assigning from untyped `gs`/`layout` calls; (3) input mapping uses absolute `event.position` vs `layout.origin` (not `to_local`); (4) `JSON.parse_string` on raw garbage logs an ERROR to stderr (still returns null) → in tests use VALID-but-wrong-shape JSON for negative controls, else the PS gate's `2>&1` escalates it to NativeCommandError; (5) `git add` a non-existent path (e.g. a `.uid`) aborts the whole add — list only real paths.
- **FINDING (human decision):** shortcut-collapse needs t-junctions (deferred) — MVP score = single-path length.

## Next session
- **Plan E5 (difficulty-onboarding)** — tune the `Difficulty.config(n)` ramp (already pinned in E1)
  + first-board onboarding/tutorial that teaches the non-obvious shortest-route scoring. The ramp
  exists; E5 is about validating its curve (build-time floor, hazard caps, ≥44dp cell cap, piece-mix)
  and a one-board guided intro. Proof = config-curve assertions + onboarding-state behavior.
- Driving inline-continuous now (no wait between chunks); ScheduleWakeup still set as a fallback.

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
- S3.2 — `FlowAnimator` (Timer step+refresh; `resolve_immediately()` headless path; `outcome_resolved` → `Main._on_outcome`). Integration: CLEARED score=8 / LEAK=3 / BOMB=2 / outlet-vs-bomb=CLEARED.
- S3.3 — outcome display: HUD outcome label + `BoardView.highlight_route` (white overlay on route cells) + bomb shake, via `Main._on_outcome`. Integration: label "CLEARED score=5", highlight==score_route (5 cells), bomb label "BOMB".
- E3 close — reflection (godot-reviewer; 2 false-positives rejected), harden (BoardView `_highlighted.clear()` + shake anchor), regression green (E1+E2 unchanged), PROOF PASS → flow-outcomes `proof-passing` (3/8).
- E4 plan — endless-run, council-clean (`_mount_board` teardown, proof asserts board dims==config(index), FlowAnimator stops Timer). Run.next_board wires config.weights (fixes E2 gap).
- S4.1 — `Run` model (RefCounted): on_clear/on_fail/next_board/restart, run-score Σ, index escalation. 6 GUT tests (control: smaller run doesn't lower high). gate 85.
- S4.2 — `SaveStore` (`scripts/save_store.gd`): high-score JSON in `user://highscore.json`; load (0 if absent/wrong-shape) / save / overwrite. 4 GUT tests (control: wrong-shape→0). gate 89.
- S4.3 — wire Main↔Run+SaveStore: `_mount_board()` (frees old _bv/_hud, resets countdown), `_on_outcome` run loop (guarded by _run!=null → E3 preserved), `_restart`, HUD run/best score + Restart btn, FlowAnimator.setup() stops Timer. Integration: RUN_SCORE=15, BOARD3_DIMS=(6,8)==config(3), RUN_OVER+HIGH=15 saved, restart→0 keeps best. E3 markers regression-green.
- S4.4 — E4 reflection BLOCKER fix: `FlowAnimator.stop()`+`is_running()`; `_mount_board` stops the animator before freeing `_bv` (Restart/advance-mid-flow no longer ticks a freed node). Integration: ANIM_RUNNING_DURING_FLOW=true→AFTER_MOUNT=false.
- E4 close — harden (typed Main fields + dropped dead guards), regression green (E2+E3 markers), PROOF PASS → endless-run `proof-passing` (4/8).
