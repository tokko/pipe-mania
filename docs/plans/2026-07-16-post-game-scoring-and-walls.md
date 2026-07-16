# Post-Game Scoring and Wall-Only Boards Implementation Plan

> **For Codex workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Award and explain a connected route's score when flow ends, then replace generated bomb hazards with denser blocked-wall layouts.

**Architecture:** The game state already knows the player-built inlet-to-outlet route before water begins through `dry_route_length()`. Capture that value at `GO`, pass it through the flow-result callback, and bank it exactly once when the round ends, regardless of clear or failure. Keep water outcome semantics intact; the run-over UI presents the evaluated route score alongside the final total. Difficulty generation emits zero bombs and moves the previous hazard pressure into blocked cells; legacy bomb model support stays untouched for existing model tests and saved boards.

**Tech Stack:** Godot 4.6.2, GDScript, GUT, Android debug APK.

**Planning evidence:** No `docs/playtests/` reports exist. Current runtime evidence shows the old post-flow wet-route score can be zero after a player made a dry connection; `GameState.dry_route_length()` is the existing source for that connection measurement.

---

### Task 1: Define end-of-flow score banking in the pure run model

**Files:**
- Modify: `scripts/model/run.gd`
- Test: `test/unit/test_run.gd`

- [ ] **Step 1: Write failing run-model tests**

Add one test that proves a connected round score is retained when the round fails, and one control that proves an unconnected round adds nothing:

```gdscript
func test_fail_banks_evaluated_connected_route() -> void:
	var r = Run.new(1)
	r.on_fail(6)
	assert_true(r.over)
	assert_eq(r.run_score, 6)
	assert_eq(r.high_score, 6)

func test_fail_with_zero_evaluation_adds_nothing() -> void:
	var r = Run.new(1)
	r.on_fail(0)
	assert_eq(r.run_score, 0)
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
& '.\tools\run-gate.ps1'
```

Expected: the new fail-banking test fails because `Run.on_fail()` has no score parameter and leaves `run_score` unchanged.

- [ ] **Step 3: Implement the minimal banking contract**

Change the model method to accept the evaluated board score, add it only on the first terminal failure, then update the high score:

```gdscript
func on_fail(score: int) -> void:
	if over:
		return
	run_score += score
	over = true
	high_score = maxi(high_score, run_score)
```

Update existing `on_fail()` calls/tests to pass `0` where they model a run with no additional connected route.
Add a duplicate-failure control that calls `on_fail(6)` twice and asserts the total is still `6`.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```powershell
& '.\tools\run-gate.ps1'
```

Expected: all run-model tests pass; no other test regresses.

### Task 2: Evaluate the placed route at GO and surface the result after flow

**Files:**
- Modify: `scripts/view/flow_animator.gd`
- Modify: `scripts/main.gd`
- Modify: `scripts/screen_controller.gd`
- Modify: `scripts/view/runover_view.gd`
- Test: `test/unit/test_scoring.gd`

- [ ] **Step 1: Write failing score-evaluation tests**

Add a scripted integration fixture using a fully placed three-cell inlet-to-outlet route with a legacy bomb adjacent to its middle cell. It must assert the GO-time route score stays `3` through the FlowAnimator callback, Run banking, high score persistence, and run-over value after the terminal failure. Keep the existing dry-route unit test as supporting coverage.

```gdscript
func test_connected_dry_route_is_the_post_game_score() -> void:
	var b = Board.new(3, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(2, 0), PT.E)
	var gs = GameState.new(b)
	for x in 3:
		gs.set_pipe(x, 0, PT.Piece.STRAIGHT, 1)
	assert_eq(gs.dry_route_length(), 3)

func test_incomplete_dry_route_scores_zero_at_evaluation() -> void:
	var b = Board.new(3, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(2, 0), PT.E)
	var gs = GameState.new(b)
	gs.set_pipe(0, 0, PT.Piece.STRAIGHT, 1)
	assert_eq(gs.dry_route_length(), 0)
```

- [ ] **Step 2: Run scripted integration and verify RED**

Run:

```powershell
$env:PIPE_TEST = '1'
& $godot --headless --path . --editor --quit-after 3
$env:PIPE_TEST = $null
```

Expected before the repair: the fixture callback emits `0` because FlowAnimator recomputes the wet score after the terminal failure. After the repair it emits and banks `3`.

- [ ] **Step 3: Carry the GO-time value through the existing result seam**

In `scripts/main.gd`, capture `var evaluated_score: int = _gs.dry_route_length()` immediately before `_gs.go()`. Extend `FlowAnimator.setup()` to accept that integer, store it, and emit it from `_finish()` and `resolve_immediately()` instead of recomputing `_gs.score()` after the flow state has changed. Update `_on_outcome(outcome, score)` to call `_run.on_clear(score)` for clears and `_run.on_fail(score)` for failures. Always pass the actual dry-route value in `PIPE_TEST`.

Keep the existing `outcome_resolved(outcome, score)` signal; its second argument continues to mean the evaluated board score. Preserve `PIPE_TEST` behavior by passing `0` or the fixture's dry route score at every direct `FlowAnimator.setup()` call.

- [ ] **Step 4: Explain the result on the run-over screen**

Extend `RunoverView.setup()` and `ScreenController.show_runover()` with an `evaluated_score: int` parameter. Render a compact explanatory line:

```gdscript
vb.add_child(UiStyle.label("Connected route: %d points" % _evaluated_score, 24))
```

The existing total label remains the authoritative run/leaderboard score. This separates “what this board earned” from “run total,” including a zero for no connection.

- [ ] **Step 5: Run the full gate and inspect scripted integration output**

Run:

```powershell
& '.\tools\run-gate.ps1'
```

Expected: all tests pass with one existing quarantined control. Confirm that existing outcome, score, run, and screen-flow integration markers still run from the `PIPE_TEST` path.

### Task 3: Replace generated bombs with walls

**Files:**
- Modify: `scripts/model/difficulty.gd`
- Test: `test/unit/test_difficulty.gd`
- Test: `test/unit/test_board_gen.gd`

- [ ] **Step 1: Write failing difficulty and generation tests**

Update the pinned difficulty rows to require zero bombs and denser blocked cells, using this wall-only ramp:

```gdscript
"bombs": 0,
"blocked": mini(area / 3, 5 + n),
```

For `n = 0`, `n = 5`, and `n = 15`, assert the exact resulting values. Add a generation property assertion that every tested difficulty board has zero `PT.Cell.BOMB` cells and the requested blocked-cell count.

- [ ] **Step 2: Run the full gate and verify RED**

Run:

```powershell
& '.\tools\run-gate.ps1'
```

Expected: difficulty rows and generated-hazard assertions fail because the current ramp still requests bombs.

- [ ] **Step 3: Implement the wall-only ramp**

In `Difficulty.config(n)`, replace the existing `bombs` and `blocked` entries with:

```gdscript
"bombs": 0,
"blocked": mini(area / 3, 5 + n),
```

Do not delete `PT.Cell.BOMB`, bomb outcome logic, or legacy bomb tests. They remain valid model behavior; generated levels simply stop selecting that hazard type.

- [ ] **Step 4: Run the full gate and verify GREEN**

Run:

```powershell
& '.\tools\run-gate.ps1'
```

Expected: generator tests confirm every generated board remains solvable and has the requested zero-bomb / exact-wall composition.

### Task 4: Verify the shipped Android flow

**Files:**
- No source changes.

- [ ] **Step 1: Build and install the debug APK**

Run:

```powershell
& '.\tools\android-preflight.ps1'
$godot = 'C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe'
if (-not (Test-Path $godot)) { $godot = 'C:\Users\andre\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' }
& $godot --headless --path . --export-debug Android 'C:\Temp\aqueduct.apk'
adb -s 3A191FDJH000K4 install -r 'C:\Temp\aqueduct.apk'
```

Expected: preflight, export, and install exit `0`.

- [ ] **Step 2: Playtest the normal entry point**

On the connected Pixel 8: start a game and confirm the board contains walls but no bomb glyphs. Complete a route and press START FLOW; the clear path advances, so confirm the next-board HUD retains the increased total. Use the deterministic legacy hazard integration fixture to prove the nonzero failed-route evaluation. Include `adb start-server`, install success, launch, and inspected captures.

---

## Self-review

- Scoring after a game ends: Tasks 1–2 capture a dry connected route at GO, preserve it through flow, bank it once, and display it at run-over.
- Zero-score connection regression: Tasks 1–2 cover both connected and zero-route controls.
- Remove bombs / add walls: Task 3 requests zero generated bombs and increases blocked cells with an explicit ramp.
- Shipped behavior: Task 4 verifies Android export and a visible device flow.
- Council revisions: callback-level proof, duplicate-failure protection, real `PIPE_TEST` invocation, and separate clear/failure device evidence address all review blockers.
- No placeholders found; every code change has a named file, test, command, and expected result.
