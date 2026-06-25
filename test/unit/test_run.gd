extends "res://addons/gut/test.gd"
## S4.1 — Run: endless-session controller. Chains boards (clear -> escalate -> next), sums
## per-board score, ends on a verify-fail; restart keeps the high score.

const Run = preload("res://scripts/model/run.gd")
const GameState = preload("res://scripts/model/game_state.gd")


func test_three_board_run_sums_score() -> void:  # acceptance: run-score = Σ board scores
	var r = Run.new(1)
	r.on_clear(3)
	r.on_clear(5)
	r.on_clear(2)
	assert_eq(r.run_score, 10, "run score is the sum of per-board scores")
	assert_eq(r.board_index, 3, "board index increments after each clear")


func test_fail_ends_run() -> void:
	var r = Run.new(1)
	r.on_clear(4)
	r.on_fail()
	assert_true(r.over, "a verify-fail ends the run")
	assert_eq(r.run_score, 4, "fail does not change the banked run score")


func test_fail_lifts_high_score() -> void:
	var r = Run.new(1)
	r.on_clear(7)
	r.on_fail()
	assert_eq(r.high_score, 7, "high score rises to the run total on fail")


func test_smaller_run_does_not_lower_high() -> void:  # control (must be able to go red)
	var r = Run.new(1)
	r.high_score = 20
	r.on_clear(5)
	r.on_fail()
	assert_eq(r.high_score, 20, "a smaller run must NOT lower the high score")


func test_restart_resets_index_and_score_keeps_high() -> void:  # acceptance: restart resets
	var r = Run.new(1)
	r.on_clear(9)
	r.on_fail()
	r.restart()
	assert_eq(r.board_index, 0, "restart resets index to 0")
	assert_eq(r.run_score, 0, "restart resets score to 0")
	assert_eq(r.high_score, 9, "high score survives restart")
	assert_false(r.over, "restart clears the over flag")


func test_next_board_escalates_grid_with_index() -> void:
	var r = Run.new(42)
	var early = r.next_board()  # index 0
	r.board_index = 9
	var late = r.next_board()  # index 9
	assert_true(late.board.width >= early.board.width, "grid width grows or holds with index")
	assert_true(late.board.height > early.board.height, "grid height escalates by index 9")
