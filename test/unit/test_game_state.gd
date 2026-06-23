extends "res://addons/gut/test.gd"
## S1.1 — GameState: owns a Board and the BUILD -> FLOW phase machine.

const Board = preload("res://scripts/model/board.gd")
const GameState = preload("res://scripts/model/game_state.gd")


func _mk() -> GameState:
	return GameState.new(Board.new(5, 5))


func test_starts_in_build_phase() -> void:
	assert_eq(_mk().phase, GameState.Phase.BUILD, "a fresh board starts in BUILD")


func test_go_transitions_to_flow() -> void:
	var gs = _mk()
	gs.go()
	assert_eq(gs.phase, GameState.Phase.FLOW, "go() starts the water race")


func test_go_is_idempotent_once_flowing() -> void:
	var gs = _mk()
	gs.go()
	gs.go()
	assert_eq(gs.phase, GameState.Phase.FLOW, "a second go() stays in FLOW")


func test_board_is_accessible() -> void:
	var b = Board.new(3, 4)
	var gs = GameState.new(b)
	assert_eq(gs.board.width, 3)
	assert_eq(gs.board.height, 4)
