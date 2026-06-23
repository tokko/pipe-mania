extends RefCounted
## Pure board model: a grid of cell types plus inlet/outlet with fixed edge
## directions. No Node deps — headless-testable.

const PT = preload("res://scripts/model/pipe_types.gd")

var width: int
var height: int
var inlet_pos: Vector2i = Vector2i(-1, -1)
var inlet_dir: int = 0
var outlet_pos: Vector2i = Vector2i(-1, -1)
var outlet_dir: int = 0

var _cells: PackedInt32Array


func _init(w: int, h: int) -> void:
	width = w
	height = h
	_cells = PackedInt32Array()
	_cells.resize(w * h)  # zero-filled == Cell.OPEN


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func cell_at(x: int, y: int) -> int:
	return _cells[y * width + x]


func set_cell(x: int, y: int, t: int) -> void:
	_cells[y * width + x] = t


func set_inlet(pos: Vector2i, dir: int) -> void:
	inlet_pos = pos
	inlet_dir = dir


func set_outlet(pos: Vector2i, dir: int) -> void:
	outlet_pos = pos
	outlet_dir = dir
