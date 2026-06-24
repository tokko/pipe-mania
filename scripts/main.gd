extends Node2D
## Entry scene + controller. Normal mode = playable board. Scripted mode (env PIPE_TEST)
## drives deterministic fixtures, prints observable state, and quits — the headless
## [integration] gate for the view (no _draw / rendering needed).
##
## Controller boundary: the VIEW (BoardView) only observes the model and emits input
## signals; THIS node performs the model mutation (place) and asks the view to refresh.

const Board = preload("res://scripts/model/board.gd")
const BoardGen = preload("res://scripts/model/board_gen.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const BoardView = preload("res://scripts/view/board_view.gd")
const FlowAnimator = preload("res://scripts/view/flow_animator.gd")
const HUD = preload("res://scripts/view/hud.gd")
const Difficulty = preload("res://scripts/model/difficulty.gd")
const Run = preload("res://scripts/model/run.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const PT = preload("res://scripts/model/pipe_types.gd")

const VIEW := Vector2i(720, 1280)
const MIN_CELL := 44
const HUD_TOP := 160

var _gs: GameState
var _bv: BoardView
var _hud: HUD
var _run: Run
var _animator: FlowAnimator
var _last_outcome := -1  # last resolved Outcome (for the headless gate / S3.3 display)
var _last_score := 0
var _current_rotation := 0  # player-chosen orientation; used only when Settings.rotation_enabled
var _build_remaining := 0.0  # build-phase countdown (E3 wires GO at zero)
var _tutorial_active := false  # first-run onboarding banner showing (dismissed on first GO)


func _ready() -> void:
	if OS.get_environment("PIPE_TEST") != "":
		_run_scripted()
		get_tree().quit()
		return
	_start_game()


func _start_game() -> void:
	_run = Run.new(randi())
	_run.high_score = SaveStore.load_high()
	_mount_first_board()


# Board 0 of a run: the onboarding tutorial board (+ banner) until tutorial_seen, else procedural
# config(0). Shared by _start_game and _restart so the tutorial state and the screen never disagree.
func _mount_first_board() -> void:
	_tutorial_active = not SaveStore.load_tutorial_seen()
	if _tutorial_active:
		_mount_board(_run.tutorial_board())
		_hud.set_tutorial("Build a path from inlet to outlet. Longer & shortcut-free = more points. Avoid bombs. Tap GO.")
	else:
		_mount_board(_run.next_board())


# The single teardown-safe board-mount path (used by _start_game, board-advance, restart).
# Frees the old view/HUD (no ghost nodes / duplicate signals) and resets the build countdown.
func _mount_board(gs) -> void:
	if _animator != null:
		_animator.stop()  # a reload/Restart mid-flow must not let a stray tick hit the freed _bv
	if _bv != null:
		_bv.queue_free()
	if _hud != null:
		_hud.queue_free()
	_gs = gs
	_bv = BoardView.new()
	add_child(_bv)
	_bv.setup(_gs, VIEW, MIN_CELL, HUD_TOP)
	_bv.cell_tapped.connect(_on_cell_tapped)
	_hud = HUD.new()
	add_child(_hud)
	_hud.bind(_bv)
	_hud.rotate_pressed.connect(cycle_rotation)
	_hud.go_pressed.connect(_start_flow)
	_hud.restart_pressed.connect(_restart)
	_hud.revive_pressed.connect(_on_revive)
	_hud.remove_ads_pressed.connect(_on_remove_ads)
	_hud.leaderboard_pressed.connect(_on_leaderboard)
	var c = Difficulty.config(_run.board_index)  # _mount_board is only ever called after _run is set
	_build_remaining = float(c.build_seconds)
	_hud.set_countdown(c.build_seconds)
	_hud.set_scores(_run.run_score, _run.high_score)


func _process(delta: float) -> void:
	if _build_remaining > 0.0:
		_build_remaining -= delta
		_hud.set_countdown(maxi(0, ceili(_build_remaining)))
		if _build_remaining <= 0.0:
			_start_flow()  # build-countdown expiry (single block; E2 council DIRECTIVE)


# Lock the build and begin the verify flow (GO button or countdown expiry). Guarded so
# button-then-expiry / re-firing can't double-start.
func _start_flow() -> void:
	if _gs.phase == GameState.Phase.FLOW:
		return
	Audio.play("go")
	if _tutorial_active:  # first GO (or countdown-expiry) dismisses the tutorial, once
		SaveStore.save_tutorial_seen(true)
		_tutorial_active = false
		if _hud != null:
			_hud.clear_tutorial()
	_gs.go()
	if _animator == null:
		_animator = FlowAnimator.new()
		add_child(_animator)
		_animator.outcome_resolved.connect(_on_outcome)
	_animator.setup(_gs, _bv)
	_animator.start()


# Verify flow resolved (animator tick loop, or resolve_immediately in the headless gate):
# show the outcome — label + scored-route highlight on clear + screen shake on bomb.
func _on_outcome(outcome: int, score: int) -> void:
	_last_outcome = outcome
	_last_score = score
	match outcome:
		GameState.Outcome.CLEARED:
			Audio.play("clear")
		GameState.Outcome.BOMB:
			Audio.play("bomb")
		GameState.Outcome.LEAK:
			Audio.play("leak")
	if _hud != null:
		_hud.set_outcome(_outcome_text(outcome, score))
	if outcome == GameState.Outcome.CLEARED:
		_bv.highlight_route(_gs.score_route())
	elif outcome == GameState.Outcome.BOMB:
		_bv.shake()
	if _run == null:
		return  # E3 standalone fixtures: no run loop
	# Run loop: clear -> bank + next board; fail -> end run + persist high score.
	if outcome == GameState.Outcome.CLEARED:
		_run.on_clear(score)
		_advance_board()  # instant advance for now; a clear-celebration beat is E6 juice
	else:
		_run.on_fail()
		SaveStore.save_high(_run.high_score)
		_hud.set_outcome(_run_end_text())


func _advance_board() -> void:
	_mount_board(_run.next_board())


func _restart() -> void:
	if _run == null:
		return
	_run.restart()
	_mount_first_board()  # re-evaluates tutorial state (restart mid-tutorial keeps it consistent)


func _run_end_text() -> String:
	return "RUN OVER  score=%d  best=%d" % [_run.run_score, _run.high_score]


# Monetization/leaderboard UI hooks -> Services (no-op stubs by default; live wiring is post-run).
func _on_revive() -> void:
	Services.ad.show_rewarded("revive")


func _on_remove_ads() -> void:
	Services.iap.purchase_remove_ads()


func _on_leaderboard() -> void:
	Services.leaderboard.submit_score(_run.run_score if _run != null else 0)


func _outcome_text(outcome: int, score: int) -> String:
	match outcome:
		GameState.Outcome.CLEARED:
			return "CLEARED  score=%d" % score
		GameState.Outcome.BOMB:
			return "BOMB"
		GameState.Outcome.LEAK:
			return "LEAK"
		_:
			return ""


func _on_cell_tapped(x: int, y: int) -> void:
	place_at(x, y)


# Controller: mutate the model (the view never does), then refresh or give invalid feedback.
func place_at(x: int, y: int) -> bool:
	if _gs.place(x, y, _effective_rotation()):
		_bv.notify_changed()
		Audio.play("place")
		return true
	_bv.shake()
	Audio.play("invalid")
	if Settings.haptics_enabled:
		Input.vibrate_handheld(40)
	return false


func _effective_rotation() -> int:
	return _current_rotation if Settings.rotation_enabled else 0


# Cycle the player-chosen orientation (only meaningful when rotation is enabled).
# NB: NOT named rotate() — that collides with Node2D.rotate(float).
func cycle_rotation() -> void:
	_current_rotation = (_current_rotation + 1) & 3


func _run_scripted() -> void:
	# --- S2.1: render-from-model check (5-wide straight line) ---
	var b = Board.new(5, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(4, 0), PT.E)
	var gs = GameState.new(b)
	for x in 5:
		gs.set_pipe(x, 0, PT.Piece.STRAIGHT, 1)
	var bv = BoardView.new()
	add_child(bv)
	bv.setup(gs, VIEW, MIN_CELL, 0)
	print("TILES=", bv.tile_count())
	print("CELL_SIZE=", bv.cell_size())
	print("DRY_ROUTE=", gs.dry_route_length())
	print("SAMPLE_20=", gs.pipe_at(2, 0))

	# --- S2.2: tap-to-place wiring (empty 3x3, all open) ---
	var b2 = Board.new(3, 3)
	b2.set_inlet(Vector2i(0, 1), PT.W)
	b2.set_outlet(Vector2i(2, 1), PT.E)
	_gs = GameState.new(b2)
	_bv = BoardView.new()
	add_child(_bv)
	_bv.setup(_gs, VIEW, MIN_CELL, 0)
	var changes := [0]
	_bv.state_changed.connect(func() -> void: changes[0] += 1)
	var ok := place_at(1, 1)  # valid open cell
	b2.set_cell(2, 2, PT.Cell.BLOCKED)
	var bad := place_at(2, 2)  # invalid (blocked)
	print("PLACE_OK=", ok, " PIECE=", _gs.pipe_at(1, 1))
	print("PLACE_BAD=", bad)
	print("STATE_CHANGED_COUNT=", changes[0])

	# --- S2.3: HUD reads model + refreshes on state_changed ---
	var b3 = Board.new(3, 1)
	b3.set_inlet(Vector2i(0, 0), PT.W)
	b3.set_outlet(Vector2i(2, 0), PT.E)
	var gs3 = GameState.new(b3)
	var bv3 = BoardView.new()
	add_child(bv3)
	bv3.setup(gs3, VIEW, MIN_CELL, 0)
	var hud = HUD.new()
	add_child(hud)
	hud.bind(bv3)
	hud.set_countdown(25)
	print("COUNTDOWN_TEXT=", hud.countdown_text())
	print("PREVIEW_LEN=", hud.preview_len())
	print("ROUTE_BEFORE=", hud.route_value())
	for x in 3:
		gs3.set_pipe(x, 0, PT.Piece.STRAIGHT, 1)
	bv3.notify_changed()  # state_changed -> HUD refresh
	print("ROUTE_AFTER=", hud.route_value())

	# --- S2.4: rotation toggle gates the placement rotation ---
	var b4 = Board.new(3, 3)
	b4.set_inlet(Vector2i(0, 1), PT.W)
	b4.set_outlet(Vector2i(2, 1), PT.E)
	_gs = GameState.new(b4)
	_bv = BoardView.new()
	add_child(_bv)
	_bv.setup(_gs, VIEW, MIN_CELL, 0)
	_current_rotation = 1
	Settings.rotation_enabled = false
	place_at(0, 0)  # rotation off -> stored rot 0
	print("ROT_OFF=", _gs.pipe_rot_at(0, 0))
	Settings.rotation_enabled = true
	place_at(1, 0)  # rotation on -> stored rot = _current_rotation
	print("ROT_ON=", _gs.pipe_rot_at(1, 0))
	print("AUDIO=", Settings.audio_enabled, " HAPTICS=", Settings.haptics_enabled)
	Settings.rotation_enabled = false  # reset

	# --- S2.5: real input path maps an absolute tap to the right cell, even with offset ---
	var b5 = Board.new(3, 3)
	b5.set_inlet(Vector2i(0, 1), PT.W)
	b5.set_outlet(Vector2i(2, 1), PT.E)
	var gs5 = GameState.new(b5)
	var bv5 = BoardView.new()
	add_child(bv5)
	bv5.setup(gs5, VIEW, MIN_CELL, 0)
	bv5.position = Vector2(50, 50)  # offset MUST NOT shift the mapping (was the to_local bug)
	var tapped := [Vector2i(-1, -1)]
	bv5.cell_tapped.connect(func(x: int, y: int) -> void: tapped[0] = Vector2i(x, y))
	var target := Vector2i(1, 2)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = bv5.layout.cell_to_pixel(target.x, target.y) + Vector2(bv5.cell_size(), bv5.cell_size()) * 0.5
	bv5._unhandled_input(ev)
	print("TAP_CELL=", tapped[0])

	# --- S3.1: GO seam -> FLOW; placement disabled in FLOW; double-start guarded ---
	var b6 = Board.new(3, 3)
	b6.set_inlet(Vector2i(0, 1), PT.W)
	b6.set_outlet(Vector2i(2, 1), PT.E)
	_gs = GameState.new(b6)
	_bv = BoardView.new()
	add_child(_bv)
	_bv.setup(_gs, VIEW, MIN_CELL, 0)
	print("PHASE_BEFORE=", _gs.phase)
	_start_flow()
	print("PHASE_AFTER_GO=", _gs.phase)
	print("PLACE_IN_FLOW=", place_at(1, 1))  # rejected during FLOW
	_start_flow()  # double-call must be a no-op (guard)
	print("PHASE_DOUBLE=", _gs.phase)
	# countdown-expiry path drives _start_flow from _process
	var b7 = Board.new(3, 3)
	b7.set_inlet(Vector2i(0, 1), PT.W)
	b7.set_outlet(Vector2i(2, 1), PT.E)
	_gs = GameState.new(b7)
	_bv = BoardView.new()
	add_child(_bv)
	_bv.setup(_gs, VIEW, MIN_CELL, 0)
	_hud = HUD.new()
	add_child(_hud)
	_hud.bind(_bv)
	_build_remaining = 0.05
	_process(0.1)  # crosses 0 -> _start_flow
	print("PHASE_AFTER_EXPIRY=", _gs.phase)

	# --- S3.2: FlowAnimator resolves fixtures via the real flow path (resolve_immediately) ---
	print("OUTCOME_ENUM NONE=", GameState.Outcome.NONE, " CLEARED=", GameState.Outcome.CLEARED,
		" BOMB=", GameState.Outcome.BOMB, " LEAK=", GameState.Outcome.LEAK)
	# connected 8-line -> CLEARED, score 8
	_resolve_fixture(_flow_line(8))
	print("FLOW_CLEAR_OUTCOME=", _last_outcome, " SCORE=", _last_score,
		" ROUTE_LEN=", _gs.score_route().size())
	# dangling 3-line -> LEAK
	var bl = Board.new(3, 1)
	bl.set_inlet(Vector2i(0, 0), PT.W)
	bl.set_outlet(Vector2i(2, 0), PT.E)
	var gl = GameState.new(bl)
	gl.set_pipe(0, 0, PT.Piece.STRAIGHT, 1)
	gl.set_pipe(1, 0, PT.Piece.STRAIGHT, 1)  # opens onto empty (2,0)
	_resolve_fixture(gl)
	print("FLOW_LEAK_OUTCOME=", _last_outcome)
	# bomb adjacent to a path cell -> BOMB
	_resolve_fixture(_flow_row(1))
	print("FLOW_BOMB_OUTCOME=", _last_outcome)
	# bomb adjacent only to the outlet -> CLEARED (outlet beats bomb same step)
	_resolve_fixture(_flow_row(2))
	print("FLOW_OUTLET_VS_BOMB_OUTCOME=", _last_outcome)

	# --- S3.3: outcome DISPLAY (HUD label + scored-route highlight + bomb shake) ---
	_gs = _flow_line(5)  # connected -> CLEARED score 5
	_bv = BoardView.new()
	add_child(_bv)
	_bv.setup(_gs, VIEW, MIN_CELL, 0)
	_hud = HUD.new()
	add_child(_hud)
	_start_flow()
	_animator.resolve_immediately()
	print("OUTCOME_LABEL=", _hud.outcome_text())
	print("HL_MATCH=", _bv.highlighted_cells() == _gs.score_route())
	print("HL_CELLS=", _bv.highlighted_cells().size(), " ROUTE_CELLS=", _gs.score_route().size())
	# bomb fixture reuses the same _hud -> label flips to "BOMB"
	_resolve_fixture(_flow_row(1))
	print("OUTCOME_LABEL_BOMB=", _hud.outcome_text())

	# --- S4.3: Run loop through Main (run-score Σ, board reload, fail->run-end, restart) ---
	var d := DirAccess.open("user://")  # clean prior high score for deterministic HIGH asserts
	if d and d.file_exists("highscore.json"):
		d.remove("highscore.json")
	_run = Run.new(7)
	_run.high_score = SaveStore.load_high()
	_mount_board(_run.next_board())  # board 0
	var c0 = Difficulty.config(0)
	print("BOARD0_DIMS=", Vector2i(_gs.board.width, _gs.board.height), " EXP=", Vector2i(c0.grid_w, c0.grid_h))
	_on_outcome(GameState.Outcome.CLEARED, 4)  # bank 4 -> advance to board 1
	var c1 = Difficulty.config(1)
	print("AFTER_C1 INDEX=", _run.board_index, " RUN=", _run.run_score,
		" DIMS=", Vector2i(_gs.board.width, _gs.board.height), " EXP=", Vector2i(c1.grid_w, c1.grid_h))
	_on_outcome(GameState.Outcome.CLEARED, 6)
	_on_outcome(GameState.Outcome.CLEARED, 5)  # now index 3, _gs is board 3
	var c3 = Difficulty.config(3)
	print("BOARD3_DIMS=", Vector2i(_gs.board.width, _gs.board.height), " EXP=", Vector2i(c3.grid_w, c3.grid_h))
	print("RUN_SCORE=", _run.run_score, " INDEX=", _run.board_index)  # expect 15, 3
	_on_outcome(GameState.Outcome.LEAK, 0)  # verify-fail ends the run
	print("RUN_OVER=", _run.over, " HIGH=", _run.high_score, " SAVED=", SaveStore.load_high())
	print("RUNEND_LABEL=", _hud.outcome_text())
	_restart()
	print("AFTER_RESTART INDEX=", _run.board_index, " RUN=", _run.run_score, " HIGH=", _run.high_score)
	print("HUD_SCORE_AFTER_RESTART=", _hud.score_text())

	# --- S4.4: _mount_board stops the flow animator (Restart/advance mid-flow safety) ---
	_run = Run.new(11)
	_gs = _flow_line(8)  # connected -> flow runs multiple steps (outcome NONE after go())
	_bv = BoardView.new()
	add_child(_bv)
	_bv.setup(_gs, VIEW, MIN_CELL, 0)
	_start_flow()  # go() + animator.start() -> Timer running (not yet resolved)
	print("ANIM_RUNNING_DURING_FLOW=", _animator.is_running())
	_mount_board(_run.next_board())  # simulates Restart/advance mid-animation
	print("ANIM_RUNNING_AFTER_MOUNT=", _animator.is_running())

	# --- E5.2: first-run onboarding tutorial ---
	var d2 := DirAccess.open("user://")  # fresh state: tutorial not seen
	if d2 and d2.file_exists("highscore.json"):
		d2.remove("highscore.json")
	_start_game()  # fresh run -> tutorial board + banner
	print("TUTORIAL_SHOWN_FRESH=", _hud.tutorial_text() != "")
	print("TUTORIAL_BOARD_DIMS=", Vector2i(_gs.board.width, _gs.board.height))  # expect (1, 5)
	_start_flow()  # first GO dismisses + flags the tutorial
	print("TUTORIAL_SEEN_AFTER_GO=", SaveStore.load_tutorial_seen())
	print("BANNER_CLEARED_AFTER_GO=", _hud.tutorial_text() == "")
	_start_game()  # second run -> tutorial already seen
	print("TUTORIAL_SHOWN_SEEN=", _hud.tutorial_text() != "")  # expect false
	print("PROC_BOARD_DIMS=", Vector2i(_gs.board.width, _gs.board.height))  # expect config(0) (5, 7)

	# --- E5.3 remediation: Restart DURING the tutorial (before GO) stays consistent ---
	var d3 := DirAccess.open("user://")
	if d3 and d3.file_exists("highscore.json"):
		d3.remove("highscore.json")
	_start_game()  # fresh -> tutorial board + banner
	_restart()  # restart BEFORE any GO (tutorial still unseen)
	print("RESTART_MID_TUT_BOARD=", Vector2i(_gs.board.width, _gs.board.height))  # expect (1, 5)
	print("RESTART_MID_TUT_BANNER=", _hud.tutorial_text() != "")  # expect true
	print("RESTART_MID_TUT_FLAG=", _tutorial_active)  # expect true (flag matches screen)

	# --- E6.1: each gameplay event maps to its SFX id ---
	_run = null  # isolate cue checks from the run loop
	_tutorial_active = false
	var b8 = Board.new(3, 3)
	b8.set_inlet(Vector2i(0, 1), PT.W)
	b8.set_outlet(Vector2i(2, 1), PT.E)
	b8.set_cell(2, 2, PT.Cell.BLOCKED)
	_gs = GameState.new(b8)
	_bv = BoardView.new()
	add_child(_bv)
	_bv.setup(_gs, VIEW, MIN_CELL, 0)
	place_at(1, 1)  # valid placement
	print("CUE_PLACE=", Audio.last_id)
	place_at(2, 2)  # blocked -> invalid
	print("CUE_INVALID=", Audio.last_id)
	_start_flow()
	print("CUE_GO=", Audio.last_id)
	_on_outcome(GameState.Outcome.CLEARED, 5)
	print("CUE_CLEAR=", Audio.last_id)
	_on_outcome(GameState.Outcome.LEAK, 0)
	print("CUE_LEAK=", Audio.last_id)
	_on_outcome(GameState.Outcome.BOMB, 0)
	print("CUE_BOMB=", Audio.last_id)

	# --- E7b: monetization/leaderboard UI hooks -> Services stubs (inert) ---
	_on_revive()
	print("HOOK_REVIVE=", Services.ad.last_call)
	_on_remove_ads()
	print("HOOK_REMOVEADS=", Services.iap.last_call)
	_run = Run.new(1)
	_run.on_clear(9)  # run_score = 9
	_on_leaderboard()
	print("HOOK_LB=", Services.leaderboard.last_call)


# Helpers for the S3.2 scripted flow checks.
func _flow_line(w: int):  # horizontal connected inlet->outlet line
	var b = Board.new(w, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(w - 1, 0), PT.E)
	var gs = GameState.new(b)
	for x in w:
		gs.set_pipe(x, 0, PT.Piece.STRAIGHT, 1)
	return gs


func _flow_row(bomb_x: int):  # 3x3 row-1 line, bomb at (bomb_x, 0)
	var b = Board.new(3, 3)
	b.set_inlet(Vector2i(0, 1), PT.W)
	b.set_outlet(Vector2i(2, 1), PT.E)
	b.set_cell(bomb_x, 0, PT.Cell.BOMB)
	var gs = GameState.new(b)
	for x in 3:
		gs.set_pipe(x, 1, PT.Piece.STRAIGHT, 1)
	return gs


func _resolve_fixture(gs) -> void:  # wire a fixture to the real flow path and resolve it
	_gs = gs
	_bv = BoardView.new()
	add_child(_bv)
	_bv.setup(_gs, VIEW, MIN_CELL, 0)
	_start_flow()
	_animator.resolve_immediately()
