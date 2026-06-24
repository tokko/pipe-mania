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
const PT = preload("res://scripts/model/pipe_types.gd")

const VIEW := Vector2i(720, 1280)
const MIN_CELL := 44
const HUD_TOP := 160

var _gs
var _bv
var _hud
var _animator
var _last_outcome := -1  # last resolved Outcome (for the headless gate / S3.3 display)
var _last_score := 0
var _current_rotation := 0  # player-chosen orientation; used only when Settings.rotation_enabled
var _build_remaining := 0.0  # build-phase countdown (E3 wires GO at zero)


func _ready() -> void:
	if OS.get_environment("PIPE_TEST") != "":
		_run_scripted()
		get_tree().quit()
		return
	_start_game()


func _start_game() -> void:
	var c = Difficulty.config(0)
	var b = BoardGen.generate(1, c.grid_w, c.grid_h, c.bombs, c.blocked)
	_gs = GameState.new(b)
	_bv = BoardView.new()
	add_child(_bv)
	_bv.setup(_gs, VIEW, MIN_CELL, HUD_TOP)
	_bv.cell_tapped.connect(_on_cell_tapped)
	_hud = HUD.new()
	add_child(_hud)
	_hud.bind(_bv)
	_hud.rotate_pressed.connect(cycle_rotation)
	_hud.go_pressed.connect(_start_flow)
	_build_remaining = float(c.build_seconds)
	_hud.set_countdown(c.build_seconds)


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
	_gs.go()
	if _animator == null:
		_animator = FlowAnimator.new()
		add_child(_animator)
		_animator.outcome_resolved.connect(_on_outcome)
	_animator.setup(_gs, _bv)
	_animator.start()


# Verify flow resolved (animator tick loop, or resolve_immediately in the headless gate).
# S3.3 wires the on-screen display (outcome label, scored-route highlight, bomb shake) here.
func _on_outcome(outcome: int, score: int) -> void:
	_last_outcome = outcome
	_last_score = score


func _on_cell_tapped(x: int, y: int) -> void:
	place_at(x, y)


# Controller: mutate the model (the view never does), then refresh or give invalid feedback.
func place_at(x: int, y: int) -> bool:
	if _gs.place(x, y, _effective_rotation()):
		_bv.notify_changed()
		return true
	_bv.shake()
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
