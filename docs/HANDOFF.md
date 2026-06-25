# HANDOFF — pipe game (working name "Aqueduct")

Autonomous `/crunch` build. Resume pointer: `.auto-sprint-board/crunch-state.json`.
Spec: `docs/DESIGN.md` · Backlog: `docs/ROADMAP.md` · Epic plan: `docs/epics/core-model.md`.

## Current state
- Gate: `tools/run-gate.ps1` (headless GUT). Green — 101 tests, 100 pass + 1 quarantined control.
- **E0 ✅ · E1–E6 ✅ · E7b ✅ — 7/8 sections `proof-passing`. E7a (android-export) APK PARK LIFTED ✅** — the APK now builds headless, installs, and BOOTS on device `RFCYA02N5LZ` (was blocked on Godot export templates + the `import_etc2_astc` project setting; both resolved 2026-06-24). To formally close the run as `done` (8/8): flip android-export → proof-passing + run the final council (pending user go-ahead).
- **Build recipe (GREEN):** `tools/android-preflight.ps1` → `godot --headless --export-debug Android build/aqueduct.apk` → `adb start-server` then `adb -s <dev> install -r`. See `docs/epics/android-export.md` "RESOLVED" section for the full gotcha list (ETC2 silent-fail, editor clobbers project.godot, adb cold-start eats install).
- **On-device UX pass (2026-06-24):** inlet/outlet markers (green ▽ in / red ▽ out), HUD "Place:" current-piece preview, tutorial widened 1×5→5×7 (fills width), action buttons moved to a bottom bar (off the grid), banner word-wraps.
- **Gameplay overhaul (2026-06-25, `e8cd356`) — supersedes several notes below:** classic Pipe-Mania placement: the deck deals pre-oriented pieces (no manual rotation — **Rotate button + `Settings.rotation_enabled` + haptics REMOVED**, superseding the S2.4 rotation note), brass dry-pipe color; one tap = one place (mouse-only input fixes the touch+mouse double-place); flow countdown **frozen until first placement**; **tutorial board DROPPED** — first board is procedural config(0) + onboarding banner (supersedes S5.x `tutorial_board`/1×5→5×7 notes); piece-type recency decay; bombs `2+n/2` / blocked `3+n/2` (board 0 now hazardous). All verified on-device.
- Model `scripts/model/` (pure, Node-free). View `scripts/view/` (`grid_layout`,`tile`,`board_view`,`flow_animator`,`hud`) + `scripts/main.gd` (controller) + `scenes/main.tscn`. Autoloads: `Config`, `Settings`, `Audio`, `Services`.
- Full endless loop: build → GO/expiry → `FlowAnimator` runs water → CLEARED banks score + advances to next (harder) board via `Run`/`_mount_board`; LEAK/BOMB → run-end + `SaveStore` high-score + Restart. HUD shows run/best score.
- **[integration] entry = `main.gd` scripted mode** (env `PIPE_TEST`), run HEADLESS via console binary, asserts stdout markers.
- **GOTCHAS:** (1) never name a Node method like a native (`rotate()`→hang); (2) view code: explicit `var x: T =` when assigning from untyped `gs`/`layout` calls; (3) input mapping uses absolute `event.position` vs `layout.origin` (not `to_local`); (4) `JSON.parse_string` on raw garbage logs an ERROR to stderr (still returns null) → in tests use VALID-but-wrong-shape JSON for negative controls, else the PS gate's `2>&1` escalates it to NativeCommandError; (5) `git add` a non-existent path (e.g. a `.uid`) aborts the whole add — list only real paths.
- **FINDING (human decision):** shortcut-collapse needs t-junctions (deferred) — MVP score = single-path length.

## Next session
- **PRIMARY (user goal): full-game polish → "fully fledged game."** Plan + build: live **leaderboards + monetization** (wire the existing `Services` ad/iap/leaderboard stubs in `scripts/services.gd` to real SDKs — needs accounts), a **splash screen**, a **start/menu screen** (game currently boots straight into a board), contextual service buttons (Revive on run-over only), and a polish pass. Start with a planning session (no code yet) to scope phases.
- **APK builds + boots on-device now** — the toolchain park is lifted. To close the run as `done`
  (8/8): flip android-export → proof-passing (its acceptance is met: APK builds headless + installs +
  boots; a fixed-seed board-clear smoke would fully satisfy #3) and run the final design-doc council.
- **Known UX follow-ups (logged this session, none blocking):** bottom button-bar uses a hardcoded
  `y=1212` — fine on portrait phones (verified) but could clip on a short/tablet aspect; move to a
  bottom-anchored Control for true responsiveness. Buttons (Revive/RemoveAds/Leaderboard) are dev
  stubs always-on — gate them contextually (Revive on run-over) in a real menu pass.
- **Optional polish** (logged in `open_reflection_items`, none gating): E6 clear-celebration beat,
  live high-score display, relaxed tutorial clock, banner safe-area; live AdMob/IAP/leaderboard wiring
  (needs accounts); trademark search before finalizing the "Aqueduct" name.

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
- E5 plan — difficulty-onboarding, council-clean (tutorial=board-0 substitute→config(1) ramp; SaveStore dict RMW; ramp acceptance owned by existing test_difficulty; screenshot=manual). Ramp already pinned (S1.7), readout+highlight built (E2/E3).
- S5.1 (E5.1) — `Run.tutorial_board()` (deterministic 1x5 vertical corridor, all-straight, completable w/o rotation) + `SaveStore` dict RMW with `tutorial_seen`. 6 GUT tests (controls: incomplete-corridor, tutorial_seen-non-clobber). gate 95.
- S5.2 (E5.2) — onboarding hook: `_start_game` mounts tutorial board + HUD banner on fresh run; first GO sets `tutorial_seen` + clears banner. HUD tutorial label. Integration: TUTORIAL_SHOWN_FRESH=true/board(1,5)→GO→SEEN=true+banner cleared→2nd run no banner+proc board(5,7). Regression E2/E3/E4 green.
- E5.3 — reflection BLOCKER fix: `_mount_first_board()` shared by `_start_game`+`_restart` (restart-mid-tutorial stays consistent: RESTART_MID_TUT_BOARD=(1,5)).
- E5 close — reflection (1 BLOCKER→E5.3), harden no-op (clean), regression green (E2/E3/E4), PROOF PASS → difficulty-onboarding `proof-passing` (5/8).
- E6 plan — juice, council-clean (proximity=Manhattan≤2; 6 cue sites enumerated; marker drives real glyph). Acceptance-driven; art/audio fidelity = manual tier (acceptance #4).
- E6.1 — `Audio` autoload (cue map + last_id); Main fires place/invalid/go/clear/leak/bomb. Integration CUE_*=sfx_*.
- E6.2 — `GameState.is_near_bomb` (Manhattan≤2) + `Tile.cell_marker` glyphs (X/spiky-ring) + near_bomb glow; `Tile.refresh` near_bomb param; BoardView passes it. 4 GUT tests (radius control + markers distinct). gate 99.
- E6 close — reflection (no BLOCKER), harden (glow on highlight/flash + marker early-return), regression green (E2-E5), PROOF PASS → juice `proof-passing` (6/8).
- E7a (android-export) PARKED — `tools/android-preflight.ps1` (acceptance #1 BLOCKED+remediation proven; on this machine only export-templates+NDK missing) + `export_presets.cfg` scaffold + `docs/store-listing.md`. Council ruling: PARKED not proof-passing (APK unbuilt). APK build+AVD smoke → `parked[]` (HIGH).
- E7b (stubbed-services) — `Services` autoload (Ad/IAP/Leaderboard no-op stubs) + HUD Revive/RemoveAds/Leaderboard hooks → Main. 3 GUT tests; integration HOOK_REVIVE/REMOVEADS/LB; #3 no-live-path structural. gate 102. PROOF PASS → stubbed-services `proof-passing` (7/8).
- TERMINAL — `drained-but-blocked`: 7/8 proof-passing, android-export parked (HIGH APK). Autonomous ceiling reached; APK is the human remainder.

### 2026-06-24 · post-crunch follow-up (APK build + on-device UX) → done · `e6203fb`
- **APK park LIFTED:** built headless + installed + booting on device `RFCYA02N5LZ`. Root cause = missing `rendering/textures/vram_compression/import_etc2_astc=true` (`f810028`); Godot 4.6.2 hides export-config errors outside the editor GUI. Installed the 1.2 GB export templates. Preflight fixed (`6cfde7f`): checks ETC2 + NDK only-for-gradle → GREEN.
- **UX (`e6203fb`, on-device verified):** inlet/outlet triangle markers, HUD "Place:" current-piece preview, tutorial 1×5→5×7 full-width, action buttons → bottom bar (off grid), banner word-wrap.
- **Caveats discovered:** Godot export errors are editor-GUI-only (read them there first, don't guess presets); the open editor re-saves/clobbers `project.godot`; `adb install -r` is silently lost to a cold daemon (`adb start-server` first). Full list in `docs/epics/android-export.md` "RESOLVED" section.
- **Review:** gate 102 green; adversarial HIGH (`draw_colored_polygon` Color arg) rejected as false-positive (correct API + verified rendering 740/1051 px); 2 MEDIUM logged (bottom-bar hardcoded y responsive caveat; HUD re-bind mitigated by `_mount_board` recreating the HUD).
- **Carry-over:** flip android-export → proof-passing + final council to close run `done` (8/8) — pending user go-ahead; responsive bottom-bar; contextual service-button gating.

### 2026-06-25 · interactive gameplay overhaul (deck orientation, UX, balance) → done · `e8cd356`
- **Shipped (user-driven, on-device verified each step):** deck deals pre-oriented pieces (`piece_queue.current_rot()`); `place(x,y)` stamps the dealt orientation — manual rotation (Rotate button, `Settings.rotation_enabled`, `_effective_rotation`) and haptics/vibration REMOVED. Brass dry-pipe color. Flow countdown frozen until first placement; prominent "Flow in Ns". Tutorial board DROPPED — first board is procedural config(0) + onboarding banner (`Run.tutorial_board()` + queue `fixed_rot` deleted). Piece-type recency decay (last-2 window ×0.5). Bombs `2+n/2` / blocked `3+n/2`.
- **Root-cause fix:** "placed tile ≠ preview / two pieces per tap" = `emulate_mouse_from_touch` firing BOTH `InputEventScreenTouch` and an emulated `InputEventMouseButton` → `BoardView._unhandled_input` now handles ONLY the mouse press (one source = one place).
- **Caveats discovered (cache these):** (a) on Android a single tap yields touch + emulated-mouse — handle one source or you double-act; (b) the spaced project path `D:\claude projects\…` trips a removal guard when Godot overwrites `build\aqueduct.apk` → export to a no-space path (`C:\Temp\aqueduct.apk`) and `adb install` from there.
- **Verification:** GUT 100 pass (101 total incl. quarantined control); behaviour witnessed on-device (placement = preview, countdown freeze, varied first board, bombs/blocks visible, no buzz).
- **Carry-over:** user's next goal = full-game polish (leaderboards, monetization, splash + start screens) — see Next session.
