extends RefCounted
## Endless-run controller: chains boards (clear -> escalate difficulty -> next), sums per-board
## score, ends on a verify-fail. Pure / Node-free -> headless-testable; Main owns one instance
## and drives it from FlowAnimator.outcome_resolved.

const Difficulty = preload("res://scripts/model/difficulty.gd")
const BoardGen = preload("res://scripts/model/board_gen.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const PieceQueue = preload("res://scripts/model/piece_queue.gd")

enum Mode {
	EASY,
	MEDIUM,
	HARD,
}

const _MODE_CONFIG := {
	Mode.EASY: {
		"name": "Easy",
		"build_seconds": 90,
		"score_numerator": 1,
		"score_denominator": 1,
	},
	Mode.MEDIUM: {
		"name": "Medium",
		"build_seconds": 60,
		"score_numerator": 3,
		"score_denominator": 2,
	},
	Mode.HARD: {
		"name": "Hard",
		"build_seconds": 30,
		"score_numerator": 2,
		"score_denominator": 1,
	},
}

var run_seed: int
var mode: int
var board_index: int = 0
var run_score: int = 0
var raw_score: int = 0
var high_score: int = 0
var over: bool = false
var revived: bool = false  # a run may be revived once (rewarded-ad continue)
var board_score_banked: bool = false


func _init(seed_: int = 0, mode_: int = Mode.EASY) -> void:
	run_seed = seed_
	mode = mode_


static func mode_config(mode_: int) -> Dictionary:
	return _MODE_CONFIG[mode_]


func build_seconds() -> int:
	return int(mode_config(mode).build_seconds)


func _scaled_score(score: int) -> int:
	var config: Dictionary = mode_config(mode)
	var numerator: int = int(config.score_numerator)
	var denominator: int = int(config.score_denominator)
	return int((score * numerator + denominator / 2) / denominator)


func _bank_score(score: int) -> void:
	if board_score_banked:
		return
	raw_score += score
	run_score = _scaled_score(raw_score)
	board_score_banked = true


## A cleared board: bank its score and advance to the next (harder) board.
func on_clear(score: int) -> void:
	_bank_score(score)
	board_index += 1
	board_score_banked = false


## A verify-fail (LEAK/BOMB): bank its score, end the run, lift the high score (never lower it).
func on_fail(score: int) -> void:
	if over:
		return
	_bank_score(score)
	over = true
	high_score = maxi(high_score, run_score)


## The GameState for the current board_index, deterministic per run_seed: a seeded board + a
## seeded, difficulty-weighted piece queue (the per-board mix the old Main dropped).
func next_board() -> GameState:
	var c = Difficulty.config(board_index)
	var blocked_rng := RandomNumberGenerator.new()
	blocked_rng.seed = run_seed + board_index
	var blocked := blocked_rng.randi_range(4, 10)
	var board = BoardGen.generate(run_seed + board_index, c.grid_w, c.grid_h, c.bombs, blocked)
	var q = PieceQueue.new(run_seed + board_index, c.weights)
	return GameState.new(board, q)


## A one-time mid-run continue (rewarded-ad revive): clear the over flag and bank the revive so
## it can't be used twice. No-op on a live run or once already revived.
func revive() -> void:
	if over and not revived:
		over = false
		revived = true


## The board to resume on after a revive: the CURRENT board, fresh, WITHOUT advancing the index
## (next_board() reads board_index and never increments — on_clear does). Named so callers don't
## reason about the index invariant.
func revive_board() -> GameState:
	return next_board()


## Restart the run (keep the high score).
func restart() -> void:
	board_index = 0
	raw_score = 0
	run_score = 0
	over = false
	revived = false
	board_score_banked = false
