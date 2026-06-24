extends Node2D
## Draws one board cell: terrain background + placed pipe (one stroke per open edge,
## per channel) + wet tint + touch highlight. Pure rendering; state pushed via refresh().

const PT = preload("res://scripts/model/pipe_types.gd")
const CG = preload("res://scripts/model/channel_graph.gd")

var size: int = 64
var cell_type: int = PT.Cell.OPEN
var piece: int = PT.Piece.NONE
var rot: int = 0
var wet: bool = false
var highlight: bool = false


func refresh(cell_type_: int, piece_: int, rot_: int, wet_: bool, highlight_: bool) -> void:
	cell_type = cell_type_
	piece = piece_
	rot = rot_
	wet = wet_
	highlight = highlight_
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(size, size)).grow(-1.0)
	var bg := Color(0.12, 0.14, 0.16)
	match cell_type:
		PT.Cell.BLOCKED:
			bg = Color(0.30, 0.30, 0.33)
		PT.Cell.BOMB:
			bg = Color(0.50, 0.12, 0.12)
	draw_rect(rect, bg)
	if highlight:
		draw_rect(rect, Color(1, 1, 1, 0.25))
	if piece != PT.Piece.NONE:
		var col := Color(0.20, 0.55, 0.90) if wet else Color(0.55, 0.60, 0.65)
		var c := Vector2(size, size) * 0.5
		var w := maxf(3.0, size * 0.18)
		for ch in CG.channels_for(piece, rot):
			for d in [PT.N, PT.E, PT.S, PT.W]:
				if ch & d:
					draw_line(c, c + _edge_off(d) * size * 0.5, col, w)


func _edge_off(d: int) -> Vector2:
	match d:
		PT.N: return Vector2(0, -1)
		PT.S: return Vector2(0, 1)
		PT.E: return Vector2(1, 0)
		PT.W: return Vector2(-1, 0)
	return Vector2.ZERO
