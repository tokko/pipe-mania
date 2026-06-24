extends RefCounted
## Pure cell<->pixel layout for the board view. Computes a square cell size that fits
## the play area but never drops below a tappable floor (min_cell); if the board can't
## fit at the floor it overflows (the view pans). No Node deps — headless-testable.

var cell_size: int
var origin: Vector2  # top-left pixel of cell (0,0)


func _init(grid_w: int, grid_h: int, viewport: Vector2i, min_cell: int, play_top: int = 0) -> void:
	var avail_w := viewport.x
	var avail_h := viewport.y - play_top
	@warning_ignore("integer_division")
	var fit := mini(avail_w / grid_w, avail_h / grid_h)
	cell_size = maxi(min_cell, fit)  # floor up: cells stay tappable even if the board overflows
	origin = Vector2(
		(avail_w - cell_size * grid_w) / 2.0,
		play_top + (avail_h - cell_size * grid_h) / 2.0,
	)


func cell_to_pixel(x: int, y: int) -> Vector2:  # top-left of the cell
	return origin + Vector2(x * cell_size, y * cell_size)


func pixel_to_cell(px: Vector2) -> Vector2i:
	return Vector2i(floori((px.x - origin.x) / cell_size), floori((px.y - origin.y) / cell_size))
