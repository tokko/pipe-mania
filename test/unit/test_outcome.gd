extends "res://addons/gut/test.gd"
## S1.5c — bomb-adjacency + clear eval, resolved per-step in the order
## CLEARED > BOMB > LEAK (so reaching the outlet beats bomb on the same step).

const Board = preload("res://scripts/model/board.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const PT = preload("res://scripts/model/pipe_types.gd")


func _line(w: int) -> GameState:  # horizontal inlet->outlet straight line
	var b = Board.new(w, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(w - 1, 0), PT.E)
	var gs = GameState.new(b)
	for x in w:
		gs.set_pipe(x, 0, PT.Piece.STRAIGHT, 1)
	return gs


func _row(bomb_x: int) -> GameState:  # 3x3, row-1 line, optional bomb cell
	var b = Board.new(3, 3)
	b.set_inlet(Vector2i(0, 1), PT.W)
	b.set_outlet(Vector2i(2, 1), PT.E)
	if bomb_x >= 0:
		b.set_cell(bomb_x, 0, PT.Cell.BOMB)
	var gs = GameState.new(b)
	for x in 3:
		gs.set_pipe(x, 1, PT.Piece.STRAIGHT, 1)
	return gs


func test_resolve_clear_on_connected_line() -> void:
	var gs = _line(3)
	gs.go()
	assert_eq(gs.resolve(), GameState.Outcome.CLEARED)


func test_is_cleared_true_after_resolve() -> void:
	var gs = _line(3)
	gs.go()
	gs.resolve()
	assert_true(gs.is_cleared(), "outlet drain channel is wet")


func test_resolve_leak_on_dangling() -> void:
	var b = Board.new(3, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(2, 0), PT.E)
	var gs = GameState.new(b)
	gs.set_pipe(0, 0, PT.Piece.STRAIGHT, 1)
	gs.set_pipe(1, 0, PT.Piece.STRAIGHT, 1)  # opens onto empty (2,0)
	gs.go()
	assert_eq(gs.resolve(), GameState.Outcome.LEAK)


func test_resolve_bomb_adjacency_fails() -> void:
	var gs = _row(1)  # bomb at (1,0), orthogonally adjacent to path cell (1,1)
	gs.go()
	assert_eq(gs.resolve(), GameState.Outcome.BOMB)


func test_no_bomb_control_clears() -> void:  # control
	var gs = _row(-1)  # same board, no bomb
	gs.go()
	assert_eq(gs.resolve(), GameState.Outcome.CLEARED, "same board without a bomb clears")


func test_outcome_now_public_none_then_clear() -> void:  # S3.1
	var gs = _line(3)
	gs.go()
	assert_eq(gs.outcome_now(), GameState.Outcome.NONE, "seed not yet at outlet")
	gs.resolve()
	assert_eq(gs.outcome_now(), GameState.Outcome.CLEARED)


func test_animator_loop_matches_resolve() -> void:  # S3.1 — closes the council gate-gap
	# Manual go() + step/outcome_now loop (mirrors FlowAnimator without a Timer) must reach
	# the SAME outcome as a fresh resolve() on the same fixture.
	var gs1 = _line(3)
	gs1.go()
	var o := gs1.outcome_now()
	var n := 0
	while o == GameState.Outcome.NONE and gs1.step() and n < 50:
		o = gs1.outcome_now()
		n += 1
	var gs2 = _line(3)
	gs2.go()
	assert_eq(o, gs2.resolve(), "manual step/outcome_now loop == resolve()")
	assert_eq(o, GameState.Outcome.CLEARED)


func test_outlet_beats_bomb_same_step() -> void:  # FX_OUTLET_VS_BOMB
	var gs = _row(2)  # bomb at (2,0), adjacent ONLY to the outlet (2,1)
	gs.go()
	assert_eq(gs.resolve(), GameState.Outcome.CLEARED,
		"reaching the outlet beats bomb-adjacency on the same step")
