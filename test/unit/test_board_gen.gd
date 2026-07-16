extends "res://addons/gut/test.gd"
## S1.2 — seeded BoardGen + cell-level (bomb-safe) solvability BFS.

const BoardGen = preload("res://scripts/model/board_gen.gd")
const Board = preload("res://scripts/model/board.gd")
const PT = preload("res://scripts/model/pipe_types.gd")
const Difficulty = preload("res://scripts/model/difficulty.gd")


func _cells_equal(a, b, w: int, h: int) -> bool:
	for y in h:
		for x in w:
			if a.cell_at(x, y) != b.cell_at(x, y):
				return false
	return true


func _count_cells(board: Board, cell_type: int) -> int:
	var count := 0
	for y in board.height:
		for x in board.width:
			if board.cell_at(x, y) == cell_type:
				count += 1
	return count


func test_generates_dimensions_and_boundary_endpoints() -> void:
	var b = BoardGen.generate(1, 7, 9, 2, 3)
	assert_eq(b.width, 7)
	assert_eq(b.height, 9)
	assert_eq(b.inlet_pos.x, 0, "inlet on left boundary")
	assert_eq(b.outlet_pos.x, 6, "outlet on right boundary")
	assert_eq(b.inlet_dir, PT.W, "inlet boundary edge is W (left)")
	assert_eq(b.outlet_dir, PT.E, "outlet boundary edge is E (right)")


func test_deterministic_for_same_seed() -> void:
	var a = BoardGen.generate(42, 8, 8, 3, 4)
	var b = BoardGen.generate(42, 8, 8, 3, 4)
	assert_eq(a.inlet_pos, b.inlet_pos)
	assert_eq(a.outlet_pos, b.outlet_pos)
	assert_true(_cells_equal(a, b, 8, 8), "same seed -> identical cells")


func test_different_seeds_differ() -> void:
	# Seed 1 skips its unsolvable candidate and returns candidate 2; start the
	# second stream at 3 so its first viable candidate cannot be the same one.
	var a = BoardGen.generate(1, 8, 8, 4, 4)
	var b = BoardGen.generate(3, 8, 8, 4, 4)
	var diff: bool = a.inlet_pos != b.inlet_pos or a.outlet_pos != b.outlet_pos or not _cells_equal(a, b, 8, 8)
	assert_true(diff, "different first-solvable candidate streams -> different boards")


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


func test_preserves_requested_hazard_counts_for_feasible_config() -> void:
	var c: Dictionary = Difficulty.config(0)
	var board: Board = BoardGen.generate(1, c.grid_w, c.grid_h, c.bombs, c.blocked)
	assert_true(BoardGen.is_solvable(board), "feasible difficulty config returns a solvable board")
	assert_eq(_count_cells(board, PT.Cell.BOMB), 0, "difficulty boards contain no bomb cells")
	assert_eq(_count_cells(board, PT.Cell.BLOCKED), c.blocked, "blocked count is preserved")


func test_difficulty_boards_are_solvable_with_requested_hazard_counts() -> void:
	for n in [0, 5, 15]:
		var c: Dictionary = Difficulty.config(n)
		for seed in range(1, 101):
			var board: Board = BoardGen.generate(seed, c.grid_w, c.grid_h, c.bombs, c.blocked)
			assert_true(BoardGen.is_solvable(board), "n=%d seed=%d is solvable" % [n, seed])
			assert_eq(_count_cells(board, PT.Cell.BOMB), 0,
				"n=%d seed=%d has no bomb cells" % [n, seed])
			assert_eq(_count_cells(board, PT.Cell.BLOCKED), c.blocked,
				"n=%d seed=%d blocked count" % [n, seed])


func test_infeasible_request_returns_null() -> void:
	var board = BoardGen.generate(3, 3, 3, 5, 0)
	assert_null(board, "infeasible hazard request returns null")


func test_generate_advances_to_the_first_solvable_candidate() -> void:
	const grid_w := 7
	const grid_h := 9
	const bombs := 0
	const blocked := 20
	const search_limit := 200
	var fixture_seed := -1
	var candidate_two: Board
	for seed in range(1, search_limit):
		var candidate_rng := RandomNumberGenerator.new()
		candidate_rng.seed = seed
		var first_candidate: Board = BoardGen._attempt(candidate_rng, grid_w, grid_h, bombs, blocked)
		candidate_rng = RandomNumberGenerator.new()
		candidate_rng.seed = seed + 1
		var next_candidate: Board = BoardGen._attempt(candidate_rng, grid_w, grid_h, bombs, blocked)
		if not BoardGen.is_solvable(first_candidate) and BoardGen.is_solvable(next_candidate):
			fixture_seed = seed
			candidate_two = next_candidate
			break

	assert_true(fixture_seed >= 0, "bounded search must find an unsolvable wall-only candidate followed by a solvable candidate")
	if fixture_seed < 0:
		return

	var generated: Board = BoardGen.generate(fixture_seed, grid_w, grid_h, bombs, blocked)
	assert_eq(generated.inlet_pos, candidate_two.inlet_pos, "candidate inlet position is preserved")
	assert_eq(generated.inlet_dir, candidate_two.inlet_dir, "candidate inlet direction is preserved")
	assert_eq(generated.outlet_pos, candidate_two.outlet_pos, "candidate outlet position is preserved")
	assert_eq(generated.outlet_dir, candidate_two.outlet_dir, "candidate outlet direction is preserved")
	assert_true(_cells_equal(generated, candidate_two, grid_w, grid_h),
		"generate returns the first solvable candidate board")
