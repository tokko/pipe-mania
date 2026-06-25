extends "res://addons/gut/test.gd"
## S1.3 — GameState placement: forced current piece, open-cell only, dry overwrite
## allowed, wet overwrite + flow-phase placement rejected.

const Board = preload("res://scripts/model/board.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const PieceQueue = preload("res://scripts/model/piece_queue.gd")
const PT = preload("res://scripts/model/pipe_types.gd")


func _gs() -> GameState:
	return GameState.new(Board.new(5, 5), PieceQueue.new(42))


func test_place_current_at_open_cell() -> void:
	var gs = _gs()
	var expected = gs.current_piece()
	var expected_rot = gs.current_rot()
	assert_true(gs.place(2, 2), "placement on an open cell succeeds")
	assert_eq(gs.pipe_at(2, 2), expected, "placed piece is the forced current")
	assert_eq(gs.pipe_rot_at(2, 2), expected_rot, "placed rotation is the deck's dealt orientation")


func test_place_advances_queue() -> void:
	var gs = _gs()
	gs.place(0, 0)
	var second = gs.current_piece()
	gs.place(0, 1)
	assert_eq(gs.pipe_at(0, 1), second, "second placement uses the advanced current")


func test_place_rejected_on_blocked() -> void:
	var b = Board.new(3, 3)
	b.set_cell(1, 1, PT.Cell.BLOCKED)
	var gs = GameState.new(b, PieceQueue.new(1))
	assert_false(gs.place(1, 1), "cannot place on a blocked cell")
	assert_eq(gs.pipe_at(1, 1), PT.Piece.NONE)


func test_place_rejected_on_bomb() -> void:
	var b = Board.new(3, 3)
	b.set_cell(1, 1, PT.Cell.BOMB)
	var gs = GameState.new(b, PieceQueue.new(1))
	assert_false(gs.place(1, 1), "cannot place on a bomb cell")


func test_place_rejected_in_flow_phase() -> void:
	var gs = _gs()
	gs.go()
	assert_false(gs.place(2, 2), "no placement during FLOW")


func test_dry_overwrite_allowed() -> void:
	var gs = _gs()
	assert_true(gs.place(2, 2))
	assert_true(gs.place(2, 2), "overwriting a DRY pipe is allowed")


func test_wet_overwrite_rejected() -> void:  # control
	var gs = _gs()
	assert_true(gs.place(2, 2))
	gs.mark_wet(2, 2)
	assert_false(gs.place(2, 2), "cannot overwrite a WET pipe")
