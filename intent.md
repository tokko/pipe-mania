# Audio, Visual Polish, and Valid-Level Generation Implementation Plan

> **For Codex workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add looping build and high-pressure flow music, retain and balance the existing gameplay sound effects, improve UI readability and presentation, and guarantee that every displayed procedural board has a bomb-safe inlet-to-outlet route without lowering its requested hazard count.

**Architecture:** Keep audio inside the existing `Audio` autoload, with separate players for one-shot effects and looped music. Keep level validity in the pure `BoardGen` model, scanning deterministic candidate seeds at the requested difficulty until it finds a bomb-safe corridor. Keep the UI code-built: `UiStyle` owns reusable visual treatment while individual views retain their current signals and controller boundaries.

**Tech Stack:** Godot 4.6.2, GDScript, procedural `AudioStreamWAV`, code-built `CanvasLayer`/`Control` UI, GUT headless tests, Android device visual/audio verification.

---

## Requirement inventory

The following are already implemented and should be preserved, not rebuilt:

| Requested capability | Existing implementation | Plan action |
| --- | --- | --- |
| Intro menu | `SplashView` -> `MenuView` through `ScreenController` | Visual polish and regression proof only |
| High score and leaderboard | `SaveStore`, `Run`, `RunoverView`, `LeaderboardView` | Preserve persistence and display |
| Score calculation and banking | `GameState.score()`, `Run.on_clear()` | Preserve exact scoring contract |
| Start water early | HUD `GO` button -> `Main._start_flow()` | Preserve phase guard and improve presentation |
| Gameplay SFX | `Audio.play()` handles place, invalid, GO, clear, leak, bomb | Keep all six cues and balance under music |
| Solvable generated boards | `BoardGen.is_solvable()` rejects blocked/bomb-adjacent corridors | Change candidate selection from density relaxation to seed skipping; add broader proof |

Do not reintroduce manual piece rotation, haptics, or the fixed tutorial board. Do not add external audio assets, plugins, or live services.

## Locked behavior

- Build music starts when a playable board is mounted.
- Flow music replaces build music immediately after the player presses `GO` or the countdown expires.
- Music stops when a run ends or returns to the menu. Clearing a board starts build music for the next board.
- The existing `Settings.audio_enabled` switch controls both music and one-shot effects.
- Existing effects remain: valid place, invalid place, GO, clear, leak, and bomb. Music must sit below them in the mix.
- A generated candidate is valid only when `BoardGen.is_solvable()` finds a route from inlet to outlet through open cells that are not orthogonally adjacent to bombs. This matches the actual water-failure rule, which is stricter than merely avoiding bomb cells.
- A rejected candidate advances to the next deterministic candidate seed. The generator must not reduce the requested bomb or blocked-cell counts to make a board pass.
- The current `PIPE_TEST` branch remains separate from the normal screen flow.

## File map

| File | Responsibility after the work |
| --- | --- |
| `scripts/audio_cues.gd` | One-shot cue synthesis plus looped build/flow music and mute-aware playback |
| `scripts/main.gd` | Chooses music at board mount, flow start, run end, and teardown |
| `scripts/screen_controller.gd` | Resynchronizes music after the audio setting changes |
| `scripts/model/board_gen.gd` | Deterministically skips invalid candidate seeds without relaxing difficulty |
| `scripts/view/ui_style.gd` | Shared palette, card, button, and label treatment |
| `scripts/view/hud.gd` | Styled status panel and visually clear GO/Menu action bar |
| `scripts/view/splash_view.gd` | Polished game identity and transition presentation |
| `scripts/view/menu_view.gd` | Polished start menu with best-score hierarchy |
| `scripts/view/runover_view.gd` | Polished score/next-action presentation |
| `scripts/view/leaderboard_view.gd` | Readable ranked local-score presentation |
| `scripts/view/settings_view.gd` | Consistent settings card and button treatment |
| `test/unit/test_audio_cues.gd` | New deterministic audio-state tests |
| `test/unit/test_board_gen.gd` | Candidate-seed and difficulty-wide solvability tests |
| `scripts/main.gd` scripted markers | Regression evidence for existing GO, score, high-score, and screen-flow behavior |

## Task 1: Make generation skip invalid candidate seeds

**Files:**

- Modify: `scripts/model/board_gen.gd:13-34`
- Modify: `test/unit/test_board_gen.gd:42-81`

- [ ] **Step 1: Add failing coverage for every active difficulty shape.**

  Extend `test_board_gen.gd` to generate a fixed seed range for board indices `0`, `5`, and `15`, using `Difficulty.config(index)`. For every result, assert the requested bomb and blocked counts are retained and `BoardGen.is_solvable(board)` is true. Add the pinned rejected-candidate fixture below: at difficulty index `0`, candidate seed `1` is invalid and candidate seed `2` is valid.

  ```gdscript
  func _count_cells(board: Board, cell_type: int) -> int:
      var count := 0
      for y in board.height:
          for x in board.width:
              if board.cell_at(x, y) == cell_type:
                  count += 1
      return count

  func test_generated_difficulty_boards_keep_hazards_and_are_bomb_safe() -> void:
      for index in [0, 5, 15]:
          var config = Difficulty.config(index)
          for seed in range(1, 101):
              var board = BoardGen.generate(seed, config.grid_w, config.grid_h, config.bombs, config.blocked)
              assert_true(BoardGen.is_solvable(board), "index %d seed %d must be playable" % [index, seed])
              assert_eq(_count_cells(board, PT.Cell.BOMB), config.bombs)
              assert_eq(_count_cells(board, PT.Cell.BLOCKED), config.blocked)

  func test_seed_one_skips_to_the_next_valid_candidate() -> void:
      var config = Difficulty.config(0)
      var first_rng := RandomNumberGenerator.new()
      first_rng.seed = 1
      var rejected = BoardGen._attempt(first_rng, config.grid_w, config.grid_h, config.bombs, config.blocked)
      assert_false(BoardGen.is_solvable(rejected), "candidate seed 1 is intentionally invalid")
      var expected_rng := RandomNumberGenerator.new()
      expected_rng.seed = 2
      var expected = BoardGen._attempt(expected_rng, config.grid_w, config.grid_h, config.bombs, config.blocked)
      assert_true(BoardGen.is_solvable(expected), "candidate seed 2 is valid")
      var actual = BoardGen.generate(1, config.grid_w, config.grid_h, config.bombs, config.blocked)
      assert_eq(actual.inlet_pos, expected.inlet_pos)
      assert_eq(actual.outlet_pos, expected.outlet_pos)
      assert_true(_cells_equal(actual, expected, config.grid_w, config.grid_h))
  ```

- [ ] **Step 2: Run the focused board-generator test and confirm the current retry behavior fails the pinned seed-skip assertion.**

  Run:

  ```powershell
  & 'C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe' --path . --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit/test_board_gen.gd -gexit
  ```

  Expected before the implementation: `test_seed_one_skips_to_the_next_valid_candidate` fails because the current generator consumes more values from one RNG rather than restarting from candidate seed `2`.

- [ ] **Step 3: Replace density relaxation with deterministic candidate-seed scanning.**

  Refactor `BoardGen.generate()` so each attempt is generated from one explicit candidate seed, beginning with the requested seed and advancing by one only after `is_solvable()` rejects the board. Keep the requested `bombs` and `blocked` values unchanged for every candidate.

  ```gdscript
  static func generate(seed_: int, w: int, h: int, bombs: int, blocked: int) -> Board:
      var candidate_seed := seed_
      while true:
          var rng := RandomNumberGenerator.new()
          rng.seed = candidate_seed
          var board := _attempt(rng, w, h, bombs, blocked)
          if is_solvable(board):
              return board
          candidate_seed += 1
  ```

  Remove `MAX_RETRIES` and the branch that decrements bombs or blocked cells. Keep `_passable()` unchanged: it already rejects bomb cells and cells orthogonally adjacent to bombs.

- [ ] **Step 4: Run the focused generator tests, then the full gate.**

  Run:

  ```powershell
  & 'C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe' --path . --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit/test_board_gen.gd -gexit
  & '.\tools\run-gate.ps1'
  ```

  Expected: every generated board is bomb-safe, requested hazard counts are preserved, determinism still holds for the same requested seed, and the full gate exits `0`.

## Task 2: Add looped build and flow music while retaining SFX

**Files:**

- Modify: `scripts/audio_cues.gd:6-83`
- Modify: `scripts/main.gd:79-132, 135-206`
- Modify: `scripts/screen_controller.gd:118-120`
- Create: `test/unit/test_audio_cues.gd`

- [ ] **Step 1: Write failing music-state tests.**

  Add a GUT test that verifies the requested music track is recorded and that disabling audio stops playback without losing the requested track. Restore `Settings.audio_enabled` at the end of each test.

  ```gdscript
  func test_music_switches_between_build_and_flow() -> void:
      Audio.set_music(Audio.MusicTrack.BUILD)
      assert_eq(Audio.current_music, Audio.MusicTrack.BUILD)
      Audio.set_music(Audio.MusicTrack.FLOW)
      assert_eq(Audio.current_music, Audio.MusicTrack.FLOW)

  func test_audio_off_stops_music_but_keeps_selected_track() -> void:
      Settings.audio_enabled = false
      Audio.set_music(Audio.MusicTrack.BUILD)
      assert_eq(Audio.current_music, Audio.MusicTrack.BUILD)
      assert_false(Audio.is_music_playing())
  ```

- [ ] **Step 2: Run the new audio test and confirm it fails because the music API does not yet exist.**

  Run:

  ```powershell
  & 'C:\Program Files\godot4\Godot_v4.6.2-stable_win64_console.exe' --path . --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit/test_audio_cues.gd -gexit
  ```

  Expected: failure for missing `MusicTrack`, `set_music`, `current_music`, or `is_music_playing`.

- [ ] **Step 3: Extend the existing audio autoload with a dedicated music player.**

  Keep `_player` for SFX and add `_music_player`, `_music_streams`, `MusicTrack`, and the small public control surface below. Build both tracks as looped procedural WAVs at startup: build is slower and consonant; flow is faster, minor/tense, and clearly more urgent. Set the music player quieter than SFX so place/GO/outcome feedback remains legible.

  ```gdscript
  enum MusicTrack { NONE, BUILD, FLOW }

  var current_music: int = MusicTrack.NONE
  var _music_player: AudioStreamPlayer
  var _music_streams := {}

  func set_music(track: int) -> void:
      current_music = track
      _music_player.stop()
      if track == MusicTrack.NONE or not Settings.audio_enabled:
          return
      _music_player.stream = _music_streams[track]
      _music_player.play()

  func sync_audio_enabled() -> void:
      set_music(current_music)

  func is_music_playing() -> bool:
      return _music_player.playing
  ```

  The music WAV builder must set `loop_mode = AudioStreamWAV.LOOP_FORWARD`, `loop_begin = 0`, and `loop_end` to the generated frame count. Do not replace the existing `CUES`, `last_id`, or one-shot synthesis; those are the SFX contract.

- [ ] **Step 4: Connect gameplay state to the music state.**

  Add the following calls without changing the current flow guard, score logic, or outcome ordering:

  ```gdscript
  # Main._mount_board(), after the board/HUD are mounted
  Audio.set_music(Audio.MusicTrack.BUILD)

  # Main._start_flow(), after the FLOW guard and before the animator begins
  Audio.set_music(Audio.MusicTrack.FLOW)

  # Main._on_outcome(), for terminal run-over only
  Audio.set_music(Audio.MusicTrack.NONE)

  # Main.teardown_game()
  Audio.set_music(Audio.MusicTrack.NONE)

  # ScreenController._on_settings_audio_toggled(), after Settings.toggle_audio()
  Audio.sync_audio_enabled()
  ```

  A board clear already calls `_advance_board()` and then `_mount_board()`, so build music resumes there automatically. Do not start music in the `PIPE_TEST` branch.

- [ ] **Step 5: Prove headless audio state and audible state transitions.**

  Add scripted markers for build, flow, and stopped music beside the existing `CUE_*` markers in `scripts/main.gd`; update the corresponding GUT integration assertion if it exists. Then run:

  ```powershell
  & '.\tools\run-gate.ps1'
  ```

  On a device, verify this exact sequence: menu is silent; Play starts build music; GO or clock expiry switches to tense flow music; clear returns to build music; leak/bomb and Menu stop music; the Audio setting mutes both music and SFX immediately.

## Task 3: Apply a focused UI visual pass

**Files:**

- Modify: `scripts/view/ui_style.gd:6-59`
- Modify: `scripts/view/hud.gd:27-67`
- Modify: `scripts/view/splash_view.gd:16-26`
- Modify: `scripts/view/menu_view.gd:22-35`
- Modify: `scripts/view/runover_view.gd:32-60`
- Modify: `scripts/view/leaderboard_view.gd:20-33`
- Modify: `scripts/view/settings_view.gd:25-40`

- [ ] **Step 1: Define the visual acceptance checks before editing views.**

  Capture the current normal gameplay screen, menu, leaderboard, settings, and run-over screen from an installed APK. Record whether each screen has: a clear title/action hierarchy, readable text over its background, at least a 44dp touch target, and no control overlap with the safe area or board.

- [ ] **Step 2: Add reusable card and button states in `UiStyle`.**

  Add factories for a dark raised card, a brass primary button, and a subdued secondary button. Use `StyleBoxFlat` overrides for normal, hover, and pressed states so the UI has tactile feedback without adding image assets.

  ```gdscript
  static func button(text: String, primary: bool = false) -> Button:
      var button := Button.new()
      button.text = text
      button.custom_minimum_size = BTN_MIN
      button.add_theme_stylebox_override("normal", _button_box(primary, 0.0))
      button.add_theme_stylebox_override("hover", _button_box(primary, 0.08))
      button.add_theme_stylebox_override("pressed", _button_box(primary, -0.08))
      return button

  static func card() -> PanelContainer:
      var panel := PanelContainer.new()
      panel.add_theme_stylebox_override("panel", _card_box())
      return panel
  ```

  Keep `backdrop()`, `centered_column()`, the palette constants, and `BTN_MIN` as the shared source of truth. Add a new `centered_card(parent)` helper for the modal screens; do not change `centered_column()` or create per-view color constants.

- [ ] **Step 3: Restyle the HUD around information hierarchy.**

  Put the countdown, run score/best score, route value, next-piece preview, and outcome text inside a top `PanelContainer` with consistent padding. Make the countdown the largest live value, make the route readout secondary, and give the GO button the primary treatment while Menu remains secondary. Keep the current anchors, `safe_top()` handling, `go_pressed`, and `menu_pressed` signals unchanged.

  ```gdscript
  _go_btn = UiStyle.button("START FLOW", true)
  var menu_btn := UiStyle.button("MENU")
  ```

  The label change is intentional: it makes the early-flow action explicit without changing the method or game rule behind it.

- [ ] **Step 4: Restyle menu, modal, and run-over views through `UiStyle`.**

  Add `centered_card(parent)` to `UiStyle`, then use it for menu, modal, and run-over content. The helper owns the full-rect center container, the panel card, padding, and the returned column. Use the primary button only for the next obvious action: Play, New Game, Revive, Submit, and Remove Ads. Keep Leaderboard, Settings, Back, and Menu secondary. Preserve every existing signal name and `ScreenController` handler.

  ```gdscript
  static func centered_card(parent: Node) -> VBoxContainer:
      var center := CenterContainer.new()
      center.set_anchors_preset(Control.PRESET_FULL_RECT)
      var panel := card()
      var margin := MarginContainer.new()
      margin.add_theme_constant_override("margin_left", 32)
      margin.add_theme_constant_override("margin_right", 32)
      margin.add_theme_constant_override("margin_top", 28)
      margin.add_theme_constant_override("margin_bottom", 28)
      var column := VBoxContainer.new()
      column.alignment = BoxContainer.ALIGNMENT_CENTER
      column.add_theme_constant_override("separation", 24)
      margin.add_child(column)
      panel.add_child(margin)
      center.add_child(panel)
      parent.add_child(center)
      return column

  var vb := UiStyle.centered_card(self)
  ```

- [ ] **Step 5: Run the gate and perform the real visual gate.**

  Run:

  ```powershell
  & '.\tools\run-gate.ps1'
  & '.\tools\android-preflight.ps1'
  ```

  If preflight is green, build and install the debug APK using the repository's documented export recipe. Verify on device at minimum: splash -> menu -> game; start-flow button visible and tappable; score/best/route readable during play; flow music transition; run-over score and high-score entry; leaderboard; settings; Menu return. Use an APK screenshot, not only the desktop Godot window, as the visual evidence.

## Task 4: Preserve the shipped gameplay contracts

**Files:**

- Modify only if a regression test reveals a real break: `scripts/main.gd`, `test/unit/test_run.gd`, `test/unit/test_save_store.gd`, and the existing `PIPE_TEST` assertions.

- [ ] **Step 1: Confirm the existing early-flow, scoring, high-score, and menu contracts remain covered.**

  The required evidence already exists in the codebase: `_start_flow()` is phase-guarded; `Run.on_clear()` banks scores; `Run.on_fail()` lifts the high score; `SaveStore` persists it; and `ScreenController` routes splash -> menu -> game -> run-over. Do not duplicate these systems.

- [ ] **Step 2: Run the full gate after every integrated audio/UI/generator batch.**

  ```powershell
  & '.\tools\run-gate.ps1'
  ```

  Expected: exit `0`, all active tests passing, and only the intentional `test_failing_control.gd` pending control. If the count changes, account for each added or removed test in the diff.

- [ ] **Step 3: Leave Git history under user control.**

  Do not commit, push, or alter ignored Claude scratch directories as part of this work. The user decides whether and when to commit the completed implementation.

## Final acceptance checklist

- [ ] Build music is audible during build and does not overlap the tense flow track.
- [ ] GO/countdown transition reliably changes to the flow track exactly once.
- [ ] Existing place, invalid, GO, clear, leak, and bomb effects remain distinct and audible over music.
- [ ] Turning Audio off stops both music and effects; turning it back on resumes the selected music state on the next synchronization.
- [ ] Every sampled generated board at active difficulty levels has an inlet-to-outlet corridor that avoids blocked cells, bomb cells, and bomb-adjacent cells.
- [ ] Rejected candidates advance by deterministic seed rather than silently reducing hazards.
- [ ] Splash, menu, settings, HUD, run-over, and leaderboard use the shared visual system; text remains readable and primary actions are obvious.
- [ ] Intro menu, high score, score banking, leaderboard, and early Start Flow action still work through their existing shipped paths.
- [ ] The headless gate is green and an installed APK verifies the visual and audio experience.
