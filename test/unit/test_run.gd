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


func test_revive_clears_over_on_failed_run() -> void:  # acceptance: revive resumes a dead run
	var r = Run.new(1)
	r.on_clear(6)
	r.on_fail()
	assert_true(r.over, "run is over before revive")
	r.revive()
	assert_false(r.over, "revive clears the over flag")
	assert_true(r.revived, "revive is banked")
	assert_eq(r.run_score, 6, "revive preserves the banked run score")
	assert_eq(r.board_index, 1, "revive does NOT advance the board index")


func test_revive_is_one_per_run() -> void:  # second revive must no-op
	var r = Run.new(1)
	r.on_fail()
	r.revive()
	r.on_fail()  # die again
	r.revive()   # the cap blocks this one
	assert_true(r.over, "a second revive does not resume the run")


func test_revive_noops_on_live_run() -> void:  # control (must be able to go red)
	var r = Run.new(1)
	r.on_clear(4)  # live run: not over
	r.revive()
	assert_false(r.over, "run stays live")
	assert_false(r.revived, "revive on a live run does NOT consume the one-time revive")
	assert_eq(r.run_score, 4, "live-run revive changes nothing")
	assert_eq(r.board_index, 1)


func test_restart_resets_revived() -> void:
	var r = Run.new(1)
	r.on_fail()
	r.revive()
	r.restart()
	assert_false(r.revived, "restart re-arms the one-time revive")
