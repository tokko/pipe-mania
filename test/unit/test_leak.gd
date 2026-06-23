extends "res://addons/gut/test.gd"
## S1.5b — leak eval. A wet channel that exposes an open edge which neither connects
## to a neighbour pipe NOR is the inlet source / outlet drain edge is leaking.

const Board = preload("res://scripts/model/board.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const PT = preload("res://scripts/model/pipe_types.gd")


func _settle(gs, max_steps := 50) -> void:
	var n := 0
	while gs.step() and n < max_steps:
		n += 1


func test_no_leak_on_connected_path() -> void:  # positive control
	var b = Board.new(3, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(2, 0), PT.E)
	var gs = GameState.new(b)
	for x in 3:
		gs.set_pipe(x, 0, PT.Piece.STRAIGHT, 1)  # E|W
	gs.go()
	_settle(gs)
	assert_false(gs.is_leaking(), "a fully connected inlet->outlet line does not leak")


func test_leak_on_dangling_open_end() -> void:  # control
	var b = Board.new(3, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(2, 0), PT.E)
	var gs = GameState.new(b)
	gs.set_pipe(0, 0, PT.Piece.STRAIGHT, 1)
	gs.set_pipe(1, 0, PT.Piece.STRAIGHT, 1)  # E mouth opens onto empty (2,0)
	gs.go()
	_settle(gs)
	assert_true(gs.is_leaking(), "a wet pipe mouth opening onto empty space leaks")


func test_leak_off_board() -> void:  # control
	var b = Board.new(1, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)  # no outlet
	var gs = GameState.new(b)
	gs.set_pipe(0, 0, PT.Piece.STRAIGHT, 1)  # E|W: W=source, E points off-board
	gs.go()
	_settle(gs)
	assert_true(gs.is_leaking(), "an open edge pointing off-board leaks")


func test_inlet_and_outlet_edges_are_not_leaks() -> void:
	var b = Board.new(2, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(1, 0), PT.E)
	var gs = GameState.new(b)
	gs.set_pipe(0, 0, PT.Piece.STRAIGHT, 1)  # W = inlet source (boundary)
	gs.set_pipe(1, 0, PT.Piece.STRAIGHT, 1)  # E = outlet drain (boundary)
	gs.go()
	_settle(gs)
	assert_false(gs.is_leaking(), "inlet source + outlet drain boundary edges are not leaks")
