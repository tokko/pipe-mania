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
const Difficulty = preload("res://scripts/model/difficulty.gd")
const PT = preload("res://scripts/model/pipe_types.gd")

const VIEW := Vector2i(720, 1280)
const MIN_CELL := 44
const HUD_TOP := 160

var _gs
var _bv
var _rotation := 0  # S2.4 wires the rotation toggle; default = fixed spawn orientation


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


func _on_cell_tapped(x: int, y: int) -> void:
	place_at(x, y)


# Controller: mutate the model (the view never does), then refresh or give invalid feedback.
func place_at(x: int, y: int) -> bool:
	if _gs.place(x, y, _rotation):
		_bv.notify_changed()
		return true
	_bv.shake()
	Input.vibrate_handheld(40)
	return false


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
