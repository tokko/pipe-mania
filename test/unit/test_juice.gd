extends "res://addons/gut/test.gd"
## E6.2 — bomb proximity warning (Manhattan <=2) + colorblind cell-type shape markers.

const Board = preload("res://scripts/model/board.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const Tile = preload("res://scripts/view/tile.gd")
const PT = preload("res://scripts/model/pipe_types.gd")


func _board_with_bomb_at(bx: int, by: int) -> GameState:
	var b = Board.new(7, 7)
	b.set_inlet(Vector2i(0, 3), PT.W)
	b.set_outlet(Vector2i(6, 3), PT.E)
	b.set_cell(bx, by, PT.Cell.BOMB)
	return GameState.new(b)


func test_is_near_bomb_radius_two() -> void:
	var gs = _board_with_bomb_at(3, 3)
	assert_true(gs.is_near_bomb(3, 4), "Manhattan 1 -> near")
	assert_true(gs.is_near_bomb(3, 5), "Manhattan 2 -> near")
	assert_true(gs.is_near_bomb(4, 4), "Manhattan 2 (diagonal 1,1) -> near")


func test_is_near_bomb_distance_three_is_not_near() -> void:  # control (radius is exactly 2)
	var gs = _board_with_bomb_at(3, 3)
	assert_false(gs.is_near_bomb(3, 6), "Manhattan 3 -> NOT near")
	assert_false(gs.is_near_bomb(0, 0), "far cell -> not near")


func test_no_bomb_board_never_near() -> void:  # control
	var b = Board.new(3, 3)
	b.set_inlet(Vector2i(0, 1), PT.W)
	b.set_outlet(Vector2i(2, 1), PT.E)
	var gs = GameState.new(b)
	assert_false(gs.is_near_bomb(1, 1), "no bomb -> never near")


func test_cell_markers_pairwise_distinct() -> void:  # colorblind: shape != hue-only
	var open_m = Tile.cell_marker(PT.Cell.OPEN)
	var blocked_m = Tile.cell_marker(PT.Cell.BLOCKED)
	var bomb_m = Tile.cell_marker(PT.Cell.BOMB)
	assert_ne(open_m, blocked_m, "OPEN vs BLOCKED markers differ")
	assert_ne(open_m, bomb_m, "OPEN vs BOMB markers differ")
	assert_ne(blocked_m, bomb_m, "BLOCKED vs BOMB markers differ")
