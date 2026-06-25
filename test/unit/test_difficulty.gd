extends "res://addons/gut/test.gd"
## S1.7 — DifficultyConfig(n): the pinned ramp table from docs/ROADMAP.md.
## Tunable in E5, but the constants live here and these tests assert them exactly.

const Difficulty = preload("res://scripts/model/difficulty.gd")
const PT = preload("res://scripts/model/pipe_types.gd")


func _assert_row(n: int, bs: int, gw: int, gh: int, bombs: int, blocked: int,
		ws: int, wc: int) -> void:
	var c = Difficulty.config(n)
	assert_eq(c.build_seconds, bs, "n=%d build_seconds" % n)
	assert_eq(c.grid_w, gw, "n=%d grid_w" % n)
	assert_eq(c.grid_h, gh, "n=%d grid_h" % n)
	assert_eq(c.bombs, bombs, "n=%d bombs" % n)
	assert_eq(c.blocked, blocked, "n=%d blocked" % n)
	assert_eq(c.weights[PT.Piece.STRAIGHT], ws, "n=%d w_straight" % n)
	assert_eq(c.weights[PT.Piece.BEND], 40, "n=%d w_bend" % n)
	assert_eq(c.weights[PT.Piece.CROSS], wc, "n=%d w_cross" % n)


func test_table_n0() -> void:
	_assert_row(0, 25, 5, 7, 2, 3, 45, 15)


func test_table_n5() -> void:
	_assert_row(5, 20, 6, 9, 4, 5, 40, 20)


func test_table_n15() -> void:
	_assert_row(15, 10, 9, 13, 9, 10, 30, 30)


func test_build_seconds_monotonic_nonincreasing() -> void:
	for n in range(1, 31):
		assert_true(Difficulty.config(n).build_seconds <= Difficulty.config(n - 1).build_seconds,
			"build_seconds must not increase at n=%d" % n)


func test_grids_stay_within_caps() -> void:
	for n in range(0, 31):
		var c = Difficulty.config(n)
		assert_true(c.grid_w <= 9, "grid_w capped at 9 (n=%d)" % n)
		assert_true(c.grid_h <= 13, "grid_h capped at 13 (n=%d)" % n)
