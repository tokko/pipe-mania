extends RefCounted
## Endless-run controller: chains boards (clear -> escalate difficulty -> next), sums per-board
## score, ends on a verify-fail. Pure / Node-free -> headless-testable; Main owns one instance
## and drives it from FlowAnimator.outcome_resolved.

const Difficulty = preload("res://scripts/model/difficulty.gd")
const BoardGen = preload("res://scripts/model/board_gen.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const PieceQueue = preload("res://scripts/model/piece_queue.gd")

var run_seed: int
var board_index: int = 0
var run_score: int = 0
var high_score: int = 0
var over: bool = false


func _init(seed_: int = 0) -> void:
	run_seed = seed_


## A cleared board: bank its score and advance to the next (harder) board.
func on_clear(score: int) -> void:
	run_score += score
	board_index += 1


## A verify-fail (LEAK/BOMB): end the run, lift the high score (never lower it).
func on_fail() -> void:
	over = true
	high_score = maxi(high_score, run_score)


## The GameState for the current board_index, deterministic per run_seed: a seeded board + a
## seeded, difficulty-weighted piece queue (the per-board mix the old Main dropped).
func next_board() -> GameState:
	var c = Difficulty.config(board_index)
	var board = BoardGen.generate(run_seed + board_index, c.grid_w, c.grid_h, c.bombs, c.blocked)
	var q = PieceQueue.new(run_seed + board_index, c.weights)
	return GameState.new(board, q)


## Restart the run (keep the high score).
func restart() -> void:
	board_index = 0
	run_score = 0
	over = false
