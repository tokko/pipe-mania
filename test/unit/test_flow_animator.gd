extends "res://addons/gut/test.gd"

const Board = preload("res://scripts/model/board.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const PT = preload("res://scripts/model/pipe_types.gd")
const BoardView = preload("res://scripts/view/board_view.gd")
const FlowAnimator = preload("res://scripts/view/flow_animator.gd")

var _emission_count := 0


func _on_outcome_resolved(_outcome: int, _score: int) -> void:
	_emission_count += 1


func _fixture() -> Dictionary:
	var board = Board.new(3, 1)
	board.set_inlet(Vector2i(0, 0), PT.W)
	board.set_outlet(Vector2i(2, 0), PT.E)
	var gs = GameState.new(board)
	for x in 3:
		gs.set_pipe(x, 0, PT.Piece.STRAIGHT, 1)

	var board_view = BoardView.new()
	add_child_autoqfree(board_view)
	board_view.setup(gs, Vector2i(720, 1280), 40)
	var animator = FlowAnimator.new()
	add_child_autoqfree(animator)
	animator.setup(gs, board_view, 3)
	return {"gs": gs, "board_view": board_view, "animator": animator}


func test_start_defaults_to_normal_tick_interval() -> void:
	var fixture := _fixture()
	var gs: GameState = fixture["gs"]
	var animator: FlowAnimator = fixture["animator"]
	gs.go()

	animator.start()

	assert_eq(animator._timer.wait_time, FlowAnimator.TICK)


func test_start_with_double_speed_uses_half_tick_interval() -> void:
	var fixture := _fixture()
	var gs: GameState = fixture["gs"]
	var animator: FlowAnimator = fixture["animator"]
	gs.go()

	var start_method: Callable = Callable(animator, "start")
	start_method.call(2.0)

	assert_true(animator.is_running(), "start(2.0) starts the flow timer")
	if animator._timer != null:
		assert_eq(animator._timer.wait_time, FlowAnimator.TICK / 2.0)


func test_resolves_once_when_immediate_then_terminal_start_repeats() -> void:
	var fixture := _fixture()
	var gs: GameState = fixture["gs"]
	var animator: FlowAnimator = fixture["animator"]
	animator.outcome_resolved.connect(_on_outcome_resolved)
	gs.go()

	animator.resolve_immediately()
	animator.start()

	var emissions := _emission_count

	assert_eq(emissions, 1, "a board resolution emits outcome_resolved exactly once")
