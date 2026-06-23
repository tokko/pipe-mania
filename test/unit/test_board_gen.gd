extends "res://addons/gut/test.gd"
## S1.2 — seeded BoardGen + cell-level (bomb-safe) solvability BFS.

const BoardGen = preload("res://scripts/model/board_gen.gd")
const Board = preload("res://scripts/model/board.gd")
const PT = preload("res://scripts/model/pipe_types.gd")


func _cells_equal(a, b, w: int, h: int) -> bool:
	for y in h:
		for x in w:
			if a.cell_at(x, y) != b.cell_at(x, y):
				return false
	return true


func test_generates_dimensions_and_boundary_endpoints() -> void:
	var b = BoardGen.generate(1, 7, 9, 2, 3)
	assert_eq(b.width, 7)
	assert_eq(b.height, 9)
	assert_eq(b.inlet_pos.x, 0, "inlet on left boundary")
	assert_eq(b.outlet_pos.x, 6, "outlet on right boundary")
	assert_eq(b.inlet_dir, PT.E)
	assert_eq(b.outlet_dir, PT.W)


func test_deterministic_for_same_seed() -> void:
	var a = BoardGen.generate(42, 8, 8, 3, 4)
	var b = BoardGen.generate(42, 8, 8, 3, 4)
	assert_eq(a.inlet_pos, b.inlet_pos)
	assert_eq(a.outlet_pos, b.outlet_pos)
	assert_true(_cells_equal(a, b, 8, 8), "same seed -> identical cells")


func test_different_seeds_differ() -> void:
	var a = BoardGen.generate(1, 8, 8, 4, 4)
	var b = BoardGen.generate(2, 8, 8, 4, 4)
	var diff: bool = a.inlet_pos != b.inlet_pos or a.outlet_pos != b.outlet_pos or not _cells_equal(a, b, 8, 8)
	assert_true(diff, "different seeds -> different boards (overwhelmingly likely)")


func test_generated_board_is_solvable() -> void:
	assert_true(BoardGen.is_solvable(BoardGen.generate(7, 7, 9, 2, 4)),
		"generated board has a bomb-safe corridor")


func test_is_solvable_accepts_open_board() -> void:  # positive control
	var b = Board.new(3, 3)
	b.set_inlet(Vector2i(0, 1), PT.E)
	b.set_outlet(Vector2i(2, 1), PT.W)
	assert_true(BoardGen.is_solvable(b), "an open board is solvable")


func test_is_solvable_rejects_blocked_wall() -> void:  # control
	var b = Board.new(3, 3)
	b.set_inlet(Vector2i(0, 1), PT.E)
	b.set_outlet(Vector2i(2, 1), PT.W)
	b.set_cell(1, 0, PT.Cell.BLOCKED)
	b.set_cell(1, 1, PT.Cell.BLOCKED)
	b.set_cell(1, 2, PT.Cell.BLOCKED)
	assert_false(BoardGen.is_solvable(b), "a full blocked wall is unsolvable")


func test_is_solvable_rejects_bomb_adjacency() -> void:  # control
	var b = Board.new(3, 3)
	b.set_inlet(Vector2i(0, 1), PT.E)
	b.set_outlet(Vector2i(2, 1), PT.W)
	b.set_cell(1, 1, PT.Cell.BOMB)
	assert_false(BoardGen.is_solvable(b), "the only corridor passes adjacent to a bomb")


func test_property_seeds_1_to_200_all_solvable() -> void:
	for s in range(1, 201):
		assert_true(BoardGen.is_solvable(BoardGen.generate(s, 7, 9, 2, 4)),
			"seed %d produced an unsolvable board" % s)


func test_reduces_density_when_overpacked() -> void:
	# 3x3 with 5 bombs is infeasible; gen must reduce density and still return solvable.
	assert_true(BoardGen.is_solvable(BoardGen.generate(3, 3, 3, 5, 0)),
		"fallback reduces density to a solvable board")
