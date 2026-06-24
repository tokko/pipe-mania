extends Node2D
## Renders a GameState's board via pooled Tile nodes (instantiated once at setup).
## Observes the pure model; never mutates it directly. Tap-to-place lands in S2.2;
## this sprint establishes pooling, rendering, and the signal contract.

const GridLayout = preload("res://scripts/view/grid_layout.gd")
const Tile = preload("res://scripts/view/tile.gd")

signal cell_tapped(x: int, y: int)
signal state_changed  # emitted by the view after a successful placement (HUD binds in S2.3)

var gs
var layout
var _tiles: Array = []  # row-major


func setup(game_state, viewport: Vector2i, min_cell: int, play_top: int = 0) -> void:
	gs = game_state
	layout = GridLayout.new(gs.board.width, gs.board.height, viewport, min_cell, play_top)
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
			_tiles[y * w + x].refresh(
				gs.board.cell_at(x, y), gs.pipe_at(x, y), gs.pipe_rot_at(x, y), gs.is_wet(x, y), false)


func cell_size() -> int:
	return layout.cell_size


func tile_count() -> int:
	return _tiles.size()
