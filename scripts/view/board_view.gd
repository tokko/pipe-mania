extends Node2D
## Renders a GameState's board via pooled Tile nodes (instantiated once at setup).
## Observes the pure model; never mutates it directly. Tap-to-place lands in S2.2;
## this sprint establishes pooling, rendering, and the signal contract.

const GridLayout = preload("res://scripts/view/grid_layout.gd")
const Tile = preload("res://scripts/view/tile.gd")

signal cell_tapped(x: int, y: int)
signal state_changed  # emitted after a successful placement; HUD refreshes on it

var gs
var layout
var _tiles: Array = []  # row-major
var _highlighted: Array = []  # cells of the last scored-route highlight (for the gate)


func setup(game_state, viewport: Vector2i, min_cell: int, play_top: int = 0) -> void:
	position = Vector2.ZERO  # clean base (a shake tween mid-reset must not leave an offset)
	gs = game_state
	layout = GridLayout.new(gs.board.width, gs.board.height, viewport, min_cell, play_top)
	_highlighted.clear()  # stale scored-route cells must not survive a board reload (E4)
	for t in _tiles:
		t.free()  # synchronous: re-setup (E4 board reload) must not leave queued-but-live tiles
	_tiles.clear()
	for y in gs.board.height:
		for x in gs.board.width:
			var t = Tile.new()
			t.size = layout.cell_size
			t.position = layout.cell_to_pixel(x, y)
			add_child(t)
			_tiles.append(t)
	refresh()


func refresh() -> void:
	var w: int = gs.board.width
	for y in gs.board.height:
		for x in w:
			var p := _port(x, y)
			_tiles[y * w + x].refresh(
				gs.board.cell_at(x, y), gs.pipe_at(x, y), gs.pipe_rot_at(x, y), gs.is_wet(x, y),
				false, gs.is_near_bomb(x, y), p.x, p.y)


# [port, dir] for a cell: 1=inlet / 2=outlet on its boundary edge, else 0. Returned as Vector2i.
func _port(x: int, y: int) -> Vector2i:
	if Vector2i(x, y) == gs.board.inlet_pos:
		return Vector2i(1, gs.board.inlet_dir)
	if Vector2i(x, y) == gs.board.outlet_pos:
		return Vector2i(2, gs.board.outlet_dir)
	return Vector2i(0, 0)


func cell_size() -> int:
	return layout.cell_size


func tile_count() -> int:
	return _tiles.size()


# Tap -> board cell -> cell_tapped signal (the controller, Main, does the actual place()).
func _unhandled_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	else:
		return
	# Absolute viewport pos vs absolute layout.origin — robust to BoardView offset (shake).
	var cell: Vector2i = layout.pixel_to_cell(pos)
	if gs.board.in_bounds(cell.x, cell.y):
		_flash(cell.x, cell.y)  # touch-down highlight
		cell_tapped.emit(cell.x, cell.y)


# Re-render from the model and notify listeners (HUD binds in S2.3).
func notify_changed() -> void:
	refresh()
	state_changed.emit()


# Highlight the scored shortest route on board-clear (Main passes gs.score_route()).
func highlight_route(cells: Array) -> void:
	_highlighted = cells.duplicate()
	var w: int = gs.board.width
	for c in cells:
		var p := _port(c.x, c.y)
		_tiles[c.y * w + c.x].refresh(
			gs.board.cell_at(c.x, c.y), gs.pipe_at(c.x, c.y), gs.pipe_rot_at(c.x, c.y),
			gs.is_wet(c.x, c.y), true, gs.is_near_bomb(c.x, c.y), p.x, p.y)


func highlighted_cells() -> Array:
	return _highlighted


# Invalid-tap / bomb feedback: a quick horizontal shake (haptic buzz is the controller's job).
func shake() -> void:
	position = Vector2.ZERO  # anchor: an overlapping shake must not stack onto a mid-shake offset
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(8, 0), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.08)


func _flash(x: int, y: int) -> void:
	var w: int = gs.board.width
	var p := _port(x, y)
	_tiles[y * w + x].refresh(
		gs.board.cell_at(x, y), gs.pipe_at(x, y), gs.pipe_rot_at(x, y), gs.is_wet(x, y), true,
		gs.is_near_bomb(x, y), p.x, p.y)
