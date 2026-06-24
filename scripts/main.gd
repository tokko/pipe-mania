extends Node2D
## Entry scene. Normal mode = playable board. Scripted mode (env PIPE_TEST set) loads a
## deterministic fixture, prints observable state to stdout, and quits — the headless
## [integration] gate for the view (no _draw / rendering needed).

const Board = preload("res://scripts/model/board.gd")
const BoardGen = preload("res://scripts/model/board_gen.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const BoardView = preload("res://scripts/view/board_view.gd")
const Difficulty = preload("res://scripts/model/difficulty.gd")
const PT = preload("res://scripts/model/pipe_types.gd")

const VIEW := Vector2i(720, 1280)
const MIN_CELL := 44
const HUD_TOP := 160


func _ready() -> void:
	if OS.get_environment("PIPE_TEST") != "":
		_run_scripted()
		get_tree().quit()
		return
	_start_game()


func _start_game() -> void:
	var c = Difficulty.config(0)
	var b = BoardGen.generate(1, c.grid_w, c.grid_h, c.bombs, c.blocked)
	var bv = BoardView.new()
	add_child(bv)
	bv.setup(GameState.new(b), VIEW, MIN_CELL, HUD_TOP)


# Deterministic fixture: a 5-wide straight inlet->outlet line. Prints observables.
func _run_scripted() -> void:
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
