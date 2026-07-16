extends "res://addons/gut/test.gd"

const Board = preload("res://scripts/model/board.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const PieceQueue = preload("res://scripts/model/piece_queue.gd")
const PT = preload("res://scripts/model/pipe_types.gd")
const BoardView = preload("res://scripts/view/board_view.gd")
const Main = preload("res://scripts/main.gd")


func _fixture(blocked: bool) -> Dictionary:
	var board = Board.new(3, 3)
	board.set_inlet(Vector2i(0, 1), PT.W)
	board.set_outlet(Vector2i(2, 1), PT.E)
	if blocked:
		board.set_cell(1, 1, PT.Cell.BLOCKED)
	var game_state = GameState.new(board, PieceQueue.new(7))
	var board_view = BoardView.new()
	add_child_autoqfree(board_view)
	board_view.setup(game_state, Vector2i(720, 1280), 40)
	var main = Main.new()
	autofree(main)
	main._gs = game_state
	main._bv = board_view
	return {"main": main, "game_state": game_state, "board_view": board_view}


func _tile(fixture: Dictionary):
	return fixture["board_view"]._tiles[1 * fixture["game_state"].board.width + 1]


func test_normal_route_successful_placement_enters_and_completes_pop() -> void:
	var fixture := _fixture(false)
	fixture["main"]._polish_active = true
	var tile = _tile(fixture)

	assert_true(fixture["main"].place_at(1, 1))
	assert_ne(fixture["game_state"].pipe_at(1, 1), PT.Piece.NONE)
	assert_gt(tile.placement_pop(), 0.0, "the placed tile must enter visible pop state")

	await get_tree().create_timer(0.03).timeout
	assert_gt(tile.placement_pop(), 0.0, "the pop must be tween-driven, not an immediate no-op")

	await get_tree().create_timer(0.25).timeout
	assert_lte(tile.placement_pop(), 0.01, "the placement pop must complete")


func test_normal_route_invalid_placement_does_not_start_pop() -> void:
	var fixture := _fixture(true)
	fixture["main"]._polish_active = true
	var tile = _tile(fixture)

	assert_false(fixture["main"].place_at(1, 1))
	assert_eq(fixture["game_state"].pipe_at(1, 1), PT.Piece.NONE)
	assert_eq(tile.placement_pop(), 0.0)


func test_scripted_route_successful_placement_does_not_start_pop() -> void:
	var fixture := _fixture(false)
	fixture["main"]._polish_active = false
	var tile = _tile(fixture)

	assert_true(fixture["main"].place_at(1, 1))
	assert_ne(fixture["game_state"].pipe_at(1, 1), PT.Piece.NONE)
	assert_eq(tile.placement_pop(), 0.0, "PIPE_TEST path must not create presentation tweens")


func test_normal_route_dry_overwrite_keeps_pop_active() -> void:
	var fixture := _fixture(false)
	fixture["main"]._polish_active = true
	var tile = _tile(fixture)

	assert_true(fixture["main"].place_at(1, 1))
	await get_tree().create_timer(0.12).timeout
	assert_gt(tile.placement_pop(), 0.0, "the first placement pop must still be active before overwrite")

	assert_true(fixture["main"].place_at(1, 1))
	await get_tree().create_timer(0.08).timeout
	assert_gt(tile.placement_pop(), 0.0, "overwriting a dry pipe must keep its placement pop active")
