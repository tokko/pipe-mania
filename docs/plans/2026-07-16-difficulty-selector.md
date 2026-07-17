# Difficulty Selector Implementation Plan

> **For Codex workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a normal-UI pre-game selector for Easy (90 seconds, 1x), Medium (60 seconds, 1.5x), and Hard (30 seconds, 2x), applying the chosen modeÃ”Ã‡Ã–s score multiplier to the integer run total.

**Architecture:** Keep selected-mode state in the pure `Run` model, alongside its existing run score and board lifecycle. `ScreenController` inserts a code-built `DifficultyView` between the menu and `Main.start_game(mode)`; `Main` uses the selected `Run` mode for every board mount in that run. Score scaling uses integer rational arithmetic on the accumulated unmodified score, rounded half-up, so persisted, HUD, leaderboard, and run-over totals remain integers.

**Tech Stack:** Godot 4.6.2, GDScript, GUT, existing `PIPE_TEST` scripted integration path, Android debug APK.

---

## Planning evidence and scope

- `docs/HANDOFF.md` is current: normal mode is `ScreenController`-driven; `PIPE_TEST` remains a separate scripted branch.
- Menu flow is currently `MenuView.play_pressed` Ã”Ã¥Ã† `ScreenController._on_menu_play()` Ã”Ã¥Ã† `Main.start_game()` ([menu view](scripts/view/menu_view.gd), [controller](scripts/screen_controller.gd)).
- `Main._mount_board()` currently obtains the build timer from `Difficulty.config(board_index)`, while `Run.on_clear()` and `Run.on_fail()` bank raw integer scores ([main](scripts/main.gd), [run model](scripts/model/run.gd)).
- The latest prior plan is `docs/plans/2026-07-16-post-game-scoring-and-walls.md`. No `docs/playtests/` directory or reports exist, so there is no newer playtest debt to package.
- Do not alter the board-generation ramp in `scripts/model/difficulty.gd`, onboarding, ads, revive behavior, leaderboard persistence, rotation behavior, or the normal `PIPE_TEST` branch structure.

## Confirmed behavior

- A `Run` survives board advance, failure, revive, and restart; it is the correct pure-model boundary for run-total scoring.
- HUD, run-over, persistence, and leaderboard scores are already integers.
- Views are code-built `CanvasLayer` classes, connected to `ScreenController` through signals.
- The normal shipped path is splash Ã”Ã¥Ã† menu Ã”Ã¥Ã† game; the scripted path does not boot the normal UI.

## Planning assumptions

- The selected time is fixed for every board in that selected run, including after a clear, restart, or revive. Board size/hazard escalation remains unchanged.
- MediumÃ”Ã‡Ã–s exact non-fractional rule is: multiply the accumulated unmodified run score by 3/2, then round halves up to a whole integer. Example: raw total `1` displays as `2`; raw total `2` displays as `3`. No float is stored or displayed.
- Direct legacy `Run.new(seed)` and `Main.start_game()` calls default to EasyÃ”Ã‡Ã–s 1x scoring only to preserve existing no-selector score behavior. The shipped UI always requires an explicit selector choice before creating a new run.
- Difficulty selection is per-run only; it is not saved as a user setting.

## File structure

| File | Change | Responsibility |
|---|---|---|
| `scripts/model/run.gd` | Modify | Defines the three selected modes, fixed build time, integer score scaling, and unmodified-score accumulator. |
| `test/unit/test_run.gd` | Modify | Proves all mode timers, multipliers, aggregate Medium rounding, and clear/fail score banking. |
| `scripts/view/difficulty_view.gd` | Create | Presents the three selector buttons and emits the selected `Run.Mode` value. |
| `scripts/screen_controller.gd` | Modify | Routes Menu Play to the selector, then starts the chosen mode. |
| `test/unit/test_difficulty_view.gd` | Create | Proves all three visible options have exact labels and emit the right mode. |
| `scripts/main.gd` | Modify | Creates `Run` with the selected mode, mounts its fixed timer, and extends only the existing scripted integration proof. |

### Task 1: Define selected modes and integer run scoring

**Files:**

- Modify: `scripts/model/run.gd`
- Test: `test/unit/test_run.gd`

- [ ] **Step 1: Write failing pure-model tests.**

Add these tests to `test/unit/test_run.gd`:

```gdscript
func test_easy_mode_uses_ninety_seconds_and_one_x_score() -> void:
	var r = Run.new(1, Run.Mode.EASY)
	assert_eq(r.build_seconds(), 90)
	r.on_clear(7)
	assert_eq(r.run_score, 7)
	assert_eq(r.raw_score, 7)


func test_medium_mode_uses_sixty_seconds_and_rounded_one_point_five_x_total() -> void:
	var r = Run.new(1, Run.Mode.MEDIUM)
	assert_eq(r.build_seconds(), 60)
	r.on_clear(1)
	assert_eq(r.run_score, 2, "1 x 1.5 rounds half up to 2")
	r.on_clear(1)
	assert_eq(r.raw_score, 2)
	assert_eq(r.run_score, 3, "the multiplier applies to the accumulated run total")


func test_hard_mode_uses_thirty_seconds_and_two_x_score() -> void:
	var r = Run.new(1, Run.Mode.HARD)
	assert_eq(r.build_seconds(), 30)
	r.on_clear(7)
	assert_eq(r.run_score, 14)
	assert_eq(r.raw_score, 7)


func test_medium_multiplier_applies_when_a_run_ends() -> void:
	var r = Run.new(1, Run.Mode.MEDIUM)
	r.on_clear(3)
	r.on_fail(1)
	assert_eq(r.raw_score, 4)
	assert_eq(r.run_score, 6)
	assert_eq(r.high_score, 6)
	assert_true(r.over)
```

- [ ] **Step 2: Run the gate and verify RED.**

Run:

```powershell
& '.\tools\run-gate.ps1'
```

Expected: RED because `Run.Mode`, the two-argument constructor, `build_seconds()`, and `raw_score` do not yet exist.

- [ ] **Step 3: Implement the complete pure-model mode contract.**

In `scripts/model/run.gd`, add this directly after the preload constants:

```gdscript
enum Mode {
	EASY,
	MEDIUM,
	HARD,
}

const _MODE_CONFIG := {
	Mode.EASY: {
		"name": "Easy",
		"build_seconds": 90,
		"score_numerator": 1,
		"score_denominator": 1,
	},
	Mode.MEDIUM: {
		"name": "Medium",
		"build_seconds": 60,
		"score_numerator": 3,
		"score_denominator": 2,
	},
	Mode.HARD: {
		"name": "Hard",
		"build_seconds": 30,
		"score_numerator": 2,
		"score_denominator": 1,
	},
}
```

Add mode and raw-score state, retaining `run_score` as the displayed/persisted integer total:

```gdscript
var mode: int
var raw_score: int = 0
```

Replace the constructor with:

```gdscript
func _init(seed_: int = 0, mode_: int = Mode.EASY) -> void:
	run_seed = seed_
	mode = mode_
```

Add these methods before `on_clear`:

```gdscript
static func mode_config(mode_: int) -> Dictionary:
	return _MODE_CONFIG[mode_]


func build_seconds() -> int:
	return int(mode_config(mode).build_seconds)


func _scaled_score(score: int) -> int:
	var config: Dictionary = mode_config(mode)
	var numerator: int = int(config.score_numerator)
	var denominator: int = int(config.score_denominator)
	return int((score * numerator + denominator / 2) / denominator)


func _bank_score(score: int) -> void:
	if board_score_banked:
		return
	raw_score += score
	run_score = _scaled_score(raw_score)
	board_score_banked = true
```

Replace the score-banking portions of both lifecycle methods:

```gdscript
func on_clear(score: int) -> void:
	_bank_score(score)
	board_index += 1
	board_score_banked = false


func on_fail(score: int) -> void:
	if over:
		return
	_bank_score(score)
	over = true
	high_score = maxi(high_score, run_score)
```

Extend `restart()` so it resets both score representations:

```gdscript
func restart() -> void:
	board_index = 0
	raw_score = 0
	run_score = 0
	over = false
	revived = false
	board_score_banked = false
```

- [ ] **Step 4: Run the pure-model gate and verify GREEN.**

Run:

```powershell
& '.\tools\run-gate.ps1'
```

Expected: exit `0`; existing 1x `Run.new(seed)` tests remain unchanged, and the new tests prove Easy `90/1x`, Medium `60/1.5x`, Hard `30/2x`, and integer aggregate rounding.

### Task 2: Add the selector view and menu-controller transition

**Files:**

- Create: `scripts/view/difficulty_view.gd`
- Modify: `scripts/screen_controller.gd`
- Test: `test/unit/test_difficulty_view.gd`

- [ ] **Step 1: Write failing selector-view coverage.**

Create `test/unit/test_difficulty_view.gd`:

```gdscript
extends "res://addons/gut/test.gd"

const DifficultyView = preload("res://scripts/view/difficulty_view.gd")
const Run = preload("res://scripts/model/run.gd")


func _button(view: DifficultyView, button_name: String) -> Button:
	return view.find_child(button_name, true, false) as Button


func test_all_difficulty_choices_are_labeled_and_emit_their_mode() -> void:
	var view := DifficultyView.new()
	var selected := []
	view.difficulty_selected.connect(func(mode: int) -> void: selected.append(mode))
	add_child(view)
	await get_tree().process_frame

	var easy := _button(view, "EasyButton")
	var medium := _button(view, "MediumButton")
	var hard := _button(view, "HardButton")

	assert_eq(easy.text, "Easy\n90 seconds | 1x score")
	assert_eq(medium.text, "Medium\n60 seconds | 1.5x score")
	assert_eq(hard.text, "Hard\n30 seconds | 2x score")

	easy.emit_signal("pressed")
	medium.emit_signal("pressed")
	hard.emit_signal("pressed")

	assert_eq(selected, [Run.Mode.EASY, Run.Mode.MEDIUM, Run.Mode.HARD])
	view.free()
```

- [ ] **Step 2: Run the gate and verify RED.**

Run:

```powershell
& '.\tools\run-gate.ps1'
```

Expected: RED because `res://scripts/view/difficulty_view.gd` does not exist.

- [ ] **Step 3: Create the selector view.**

Create `scripts/view/difficulty_view.gd`:

```gdscript
extends CanvasLayer

signal difficulty_selected(mode: int)

const Run = preload("res://scripts/model/run.gd")
const UiStyle = preload("res://scripts/view/ui_style.gd")


func _init() -> void:
	layer = 5


func _ready() -> void:
	add_child(UiStyle.backdrop())
	var column := UiStyle.centered_card(self)
	column.add_child(UiStyle.title("CHOOSE DIFFICULTY", 44))
	_add_mode_button(column, Run.Mode.EASY, true)
	_add_mode_button(column, Run.Mode.MEDIUM, false)
	_add_mode_button(column, Run.Mode.HARD, false)


func _add_mode_button(column: VBoxContainer, mode: int, primary: bool) -> void:
	var config: Dictionary = Run.mode_config(mode)
	var button := UiStyle.button(
		"%s\n%d seconds | %sx score" % [
			str(config.name),
			int(config.build_seconds),
			"1.5" if int(config.score_denominator) == 2 else str(int(config.score_numerator)),
		],
		primary
	)
	button.name = "%sButton" % str(config.name)
	button.pressed.connect(difficulty_selected.emit.bind(mode))
	column.add_child(button)


func connect_view(controller) -> void:
	difficulty_selected.connect(controller._on_difficulty_selected)
```

- [ ] **Step 4: Route Play through the selector.**

In `scripts/screen_controller.gd`, add the preload with the existing view preloads:

```gdscript
const DifficultyView = preload("res://scripts/view/difficulty_view.gd")
```

Replace the Play handler and add the selector handler:

```gdscript
func _on_menu_play() -> void:
	_screen_view = _swap(_screen_view, DifficultyView.new())


func _on_difficulty_selected(mode: int) -> void:
	_screen_view = _swap(_screen_view, null)
	_main.start_game(mode)
```

Extend `screen_label()` before the `MenuView` branch:

```gdscript
	if _screen_view is DifficultyView:
		return "DIFFICULTY"
```

- [ ] **Step 5: Run the gate and verify GREEN.**

Run:

```powershell
& '.\tools\run-gate.ps1'
```

Expected: exit `0`; the selector test proves all three visible choices and their emitted model values. Existing menu, leaderboard, settings, and run-over tests remain green.

### Task 3: Start the selected mode and extend only the necessary scripted proof

**Files:**

- Modify: `scripts/main.gd`

**Dependencies:** Tasks 1 and 2 are green.

- [ ] **Step 1: Add the failing scripted integration assertions before changing the start contract.**

In the existing E8 screen-flow section of `_run_scripted()`, replace the current immediate-game expectation after `_screen._on_menu_play()` with:

```gdscript
var run_before_selection := _run
_screen._on_menu_play()
print("SCREEN_AFTER_PLAY=", _screen.screen_label(),
	" RUN_UNCHANGED=", _run == run_before_selection)
_screen._on_difficulty_selected(Run.Mode.MEDIUM)
print("MEDIUM_STARTED=", _screen.screen_label() == "GAME"
	and _run.mode == Run.Mode.MEDIUM,
	" TIMER=", _hud.countdown_text())
```

- [ ] **Step 2: Run the scripted integration and verify RED.**

Run:

```powershell
$godot = 'C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe'
if (-not (Test-Path $godot)) {
	$godot = 'C:\Users\andre\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
}
$env:PIPE_TEST = '1'
try {
	$output = & $godot --headless --path . 2>&1
	$exitCode = $LASTEXITCODE
} finally {
	Remove-Item Env:PIPE_TEST -ErrorAction SilentlyContinue
}
$output
if ($exitCode -ne 0) { exit $exitCode }
$output | Select-String -SimpleMatch 'MEDIUM_STARTED=true TIMER=Flow in 60s'
```

Expected: RED because `Main.start_game()` does not yet accept a mode and `_mount_board()` still uses the board-ramp timer.

- [ ] **Step 3: Wire the selected mode into run creation and board mounting.**

Replace `_start_game()` with:

```gdscript
func _start_game(mode: int = Run.Mode.EASY) -> void:
	_run = Run.new(randi(), mode)
	_run.high_score = SaveStore.load_high()
	_mount_first_board()
```

In `_mount_board()`, replace the timer setup:

```gdscript
	var c = Difficulty.config(_run.board_index)
	_build_remaining = float(c.build_seconds)
	_clock_started = false
	_hud.set_countdown(c.build_seconds)
```

with:

```gdscript
	var build_seconds := _run.build_seconds()
	_build_remaining = float(build_seconds)
	_clock_started = false
	_hud.set_countdown(build_seconds)
```

Replace the public normal-UI entry point with:

```gdscript
func start_game(mode: int = Run.Mode.EASY) -> void:
	_maybe_show_interstitial()
	_start_game(mode)
```

Do not route `PIPE_TEST` through the shipped selector. Its existing script remains separate; it only gains the explicit E8 assertions above.

- [ ] **Step 4: Run the full automated proof and verify GREEN.**

Run:

```powershell
& '.\tools\run-gate.ps1'
```

Then rerun:

```powershell
$godot = 'C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe'
if (-not (Test-Path $godot)) {
	$godot = 'C:\Users\andre\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
}
$env:PIPE_TEST = '1'
try {
	$output = & $godot --headless --path . 2>&1
	$exitCode = $LASTEXITCODE
} finally {
	Remove-Item Env:PIPE_TEST -ErrorAction SilentlyContinue
}
$output
if ($exitCode -ne 0) { exit $exitCode }
$output | Select-String -SimpleMatch 'SCREEN_AFTER_PLAY=DIFFICULTY RUN_UNCHANGED=true'
$output | Select-String -SimpleMatch 'MEDIUM_STARTED=true TIMER=Flow in 60s'
```

Expected: both commands exit `0`. The scripted path proves Play displays the selector without constructing a new run, then a Medium selection creates the Medium run and mounts a 60-second HUD.

### Task 4: Verify the shipped non-`PIPE_TEST` UI

**Files:**

- No source changes.

- [ ] **Step 1: Run the normal visible entry point.**

Run:

```powershell
& '.\tools\run-game.ps1' -QuitAfter 180
```

Expected: normal splash Ã”Ã¥Ã† menu flow appears, without `PIPE_TEST`.

- [ ] **Step 2: Perform the visible selector checks.**

From the normal menu:

1. Tap **Play** and confirm the selector shows exactly:
   - `Easy`, `90 seconds`, `1x score`
   - `Medium`, `60 seconds`, `1.5x score`
   - `Hard`, `30 seconds`, `2x score`
2. Start Easy and confirm the build HUD says `Flow in 90s`.
3. Return to Menu, start Medium, and confirm `Flow in 60s`.
4. Return to Menu, start Hard, and confirm `Flow in 30s`.
5. Confirm no selector appears in the scripted headless run and that normal gameplay still accepts one mouse-emulated touch placement per tap.

- [ ] **Step 3: Build and install the Android debug APK when the connected device is available.**

Run:

```powershell
& '.\tools\android-preflight.ps1'

$godot = 'C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe'
if (-not (Test-Path $godot)) {
	$godot = 'C:\Users\andre\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
}

& $godot --headless --path . --export-debug Android 'C:\Temp\aqueduct.apk'
adb start-server
adb -s 3A191FDJH000K4 install -r 'C:\Temp\aqueduct.apk'
```

Expected: preflight, export, and install exit `0`. Repeat the visible selector checks on the installed APK. If the device is unavailable, record only this visual gate as blocked; do not claim APK evidence.

---

## Acceptance criteria

- Easy starts a new run with `Flow in 90s` and 1x score.
- Medium starts a new run with `Flow in 60s` and a 3/2 multiplier.
- Hard starts a new run with `Flow in 30s` and 2x score.
- Play opens the selector before a new run is constructed; selecting a mode starts that mode.
- `Run.run_score`, high score, HUD total, run-over total, and leaderboard value remain integers. Medium uses aggregate rational scaling with half-up rounding; no fractional value is stored or displayed.
- Clear and failure both bank the selected multiplier correctly; revive does not re-bank a score; restart resets both raw and displayed totals.
- Existing default/no-selector score tests remain 1x-compatible, and the `PIPE_TEST` branch stays separate with only the required integration assertions.
- Full GUT gate exits `0` with positive passing/assertion counts and exactly the existing intentional pending control.
- Visible normal-UI verification covers all three choices and their displayed timers.

## Execution packet / write-set map

| Package | Profile | Owner files | Dependencies | Definition of done | Validation |
|---|---|---|---|---|---|
| P0: branch and baseline | Root | No writes | None | Confirm `feature/difficulty-selector` is checked out, `main` is its base, preserve current untracked `.codex/` and `.uid` files. No commit. | `git status --short --branch`; `git merge-base --is-ancestor main HEAD` |
| P1: model tests | `test_writer` | `test/unit/test_run.gd` | P0 | Failing tests define all timer/multiplier/rounding contracts. | `& '.\tools\run-gate.ps1'` must be red for missing contract. |
| P2: run model | `implementer_standard` | `scripts/model/run.gd` | P1 | Implements modes, raw integer total, half-up aggregate Medium scaling, fixed mode timer, restart reset. | `& '.\tools\run-gate.ps1'` exit `0`. |
| P3: selector tests | `test_writer` | `test/unit/test_difficulty_view.gd` | P0 | Failing UI test requires all labels and selected-mode emissions. | `& '.\tools\run-gate.ps1'` red because the view is absent. |
| P4: selector UI | `implementer_standard` | `scripts/view/difficulty_view.gd`, `scripts/screen_controller.gd` | P2, P3 | Play opens selector; each option emits a mode; selected mode is passed to Main. | `& '.\tools\run-gate.ps1'` exit `0`. |
| P5: main integration | `implementer_standard` | `scripts/main.gd` | P2, P4 | Main constructs the selected Run, uses its timer, and adds only required `PIPE_TEST` selector proof. | Full GUT gate plus the explicit `PIPE_TEST` command in Task 3. |
| P6: final verification | Root | No writes | P5 | Run final automated and visible shipped-entry-point checks; report unavailable device evidence precisely. | Task 3 and Task 4 commands. |

No two packages write the same file. P1/P3 may be authored in parallel; P2 and P4 may then proceed independently; P5 waits for both contracts.

## Council routing

This is Tier 2: a cross-feature interaction among pure scoring, controller flow, and Godot UI. Before implementation, root should obtain one parallel council pass from `contract_reviewer`, `technical_reviewer`, and `godot_reviewer`. Medium-or-higher findings return to this planner profile for revision. Do not commit unless the user separately asks.

## Self-review

- All three requested time/multiplier pairs are covered by model tests and visible UI checks.
- Selection-before-start is covered by the real controller route in `PIPE_TEST`.
- The score rule is explicit for odd Medium totals and preserves integer storage/display.
- Existing no-selector score behavior is protected by the Easy default; normal shipped UI still requires a selector choice.
- No playtest reports or debt items exist to add.
- No unrelated board-ramp, onboarding, services, generated files, or build configuration changes are included.
