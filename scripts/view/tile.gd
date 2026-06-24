extends Node2D
## Draws one board cell: terrain background + placed pipe (one stroke per open edge,
## per channel) + wet tint + touch highlight. Pure rendering; state pushed via refresh().

const PT = preload("res://scripts/model/pipe_types.gd")
const CG = preload("res://scripts/model/channel_graph.gd")
const _DIRS := [PT.N, PT.E, PT.S, PT.W]  # hoisted: avoid per-_draw array allocation

var size: int = 64
var cell_type: int = PT.Cell.OPEN
var piece: int = PT.Piece.NONE
var rot: int = 0
var wet: bool = false
var highlight: bool = false
var near_bomb: bool = false


func refresh(cell_type_: int, piece_: int, rot_: int, wet_: bool, highlight_: bool,
		near_bomb_: bool = false) -> void:
	cell_type = cell_type_
	piece = piece_
	rot = rot_
	wet = wet_
	highlight = highlight_
	near_bomb = near_bomb_
	queue_redraw()


## Distinct SHAPE-marker id per cell type so types are readable WITHOUT hue (colorblind-safe):
## 0 = none (OPEN), 1 = X/hatch (BLOCKED), 2 = spiky ring (BOMB). _draw renders the glyph.
static func cell_marker(ct: int) -> int:
	match ct:
		PT.Cell.BOMB:
			return 2
		PT.Cell.BLOCKED:
			return 1
		_:
			return 0


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
	if near_bomb:  # proximity warning outline (orange), readable independent of hue via its border
		draw_rect(rect, Color(1.0, 0.75, 0.0), false, maxf(2.0, size * 0.06))
	_draw_marker(rect)
	if piece != PT.Piece.NONE:
		var col := Color(0.20, 0.55, 0.90) if wet else Color(0.55, 0.60, 0.65)
		var c := Vector2(size, size) * 0.5
		var w := maxf(3.0, size * 0.18)
		for ch in CG.channels_for(piece, rot):
			for d in _DIRS:
				if ch & d:
					draw_line(c, c + _edge_off(d) * size * 0.5, col, w)


# Colorblind-safe SHAPE per cell type (X for blocked, spiky ring for bomb) so the type reads
# without relying on the background hue.
func _draw_marker(rect: Rect2) -> void:
	var marker := cell_marker(cell_type)
	if marker == 0:  # OPEN: no glyph
		return
	var c := rect.position + rect.size * 0.5
	var r := size * 0.22
	match marker:
		1:  # BLOCKED: an X
			var w := maxf(2.0, size * 0.08)
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), Color(0.85, 0.85, 0.88), w)
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), Color(0.85, 0.85, 0.88), w)
		2:  # BOMB: a spiky ring
			var w := maxf(2.0, size * 0.08)
			draw_arc(c, r, 0.0, TAU, 16, Color(1, 0.9, 0.2), w)
			for i in 8:
				var a := TAU * i / 8.0
				var dir := Vector2(cos(a), sin(a))
				draw_line(c + dir * r, c + dir * r * 1.5, Color(1, 0.9, 0.2), maxf(1.5, size * 0.05))


func _edge_off(d: int) -> Vector2:
	match d:
		PT.N: return Vector2(0, -1)
		PT.S: return Vector2(0, 1)
		PT.E: return Vector2(1, 0)
		PT.W: return Vector2(-1, 0)
	return Vector2.ZERO
