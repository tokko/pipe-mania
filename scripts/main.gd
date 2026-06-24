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
const HUD = preload("res://scripts/view/hud.gd")
const Difficulty = preload("res://scripts/model/difficulty.gd")
const PT = preload("res://scripts/model/pipe_types.gd")

const VIEW := Vector2i(720, 1280)
const MIN_CELL := 44
const HUD_TOP := 160

var _gs
var _bv
var _hud
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
	_build_remaining = float(c.build_seconds)
	_hud.set_countdown(c.build_seconds)


func _process(delta: float) -> void:
	if _build_remaining > 0.0:
		_build_remaining -= delta
		_hud.set_countdown(maxi(0, ceili(_build_remaining)))


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
