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
var port: int = 0  # 0 none, 1 inlet, 2 outlet
var port_dir: int = 0  # boundary edge (N/E/S/W bitmask)
var _placement_pop := 0.0
var _placement_tween: Tween


func refresh(cell_type_: int, piece_: int, rot_: int, wet_: bool, highlight_: bool,
		near_bomb_: bool = false, port_: int = 0, port_dir_: int = 0) -> void:
	cell_type = cell_type_
	piece = piece_
	rot = rot_
	wet = wet_
	highlight = highlight_
	near_bomb = near_bomb_
	port = port_
	port_dir = port_dir_
	queue_redraw()


func placement_pop() -> float:
	return _placement_pop


func play_placement() -> void:
	if _placement_tween != null and _placement_tween.is_valid() and _placement_tween.is_running():
		_placement_tween.kill()
	_set_placement_pop(1.0)
	_placement_tween = create_tween()
	_placement_tween.tween_method(_set_placement_pop, 1.0, 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_placement_pop(value: float) -> void:
	_placement_pop = value
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
	draw_rect(Rect2(rect.position + Vector2(0, size * 0.07), rect.size), Color(0.02, 0.07, 0.08, 0.65))
	var bg := Color(0.08, 0.28, 0.31)
	match cell_type:
		PT.Cell.BLOCKED:
			bg = Color(0.25, 0.30, 0.32)
		PT.Cell.BOMB:
			bg = Color(0.50, 0.14, 0.16)
	draw_rect(rect, bg)
	draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(rect.size.x - 2, 2), Color(0.55, 0.95, 0.90, 0.5), maxf(1.0, size * 0.025))
	draw_line(rect.position + Vector2(2, rect.size.y - 2), rect.position + Vector2(rect.size.x - 2, rect.size.y - 2), Color(0.02, 0.10, 0.12, 0.8), maxf(1.0, size * 0.035))
	if highlight:
		draw_rect(rect, Color(1, 1, 1, 0.25))
	if near_bomb:  # proximity warning outline (orange), readable independent of hue via its border
		draw_rect(rect, Color(1.0, 0.75, 0.0), false, maxf(2.0, size * 0.06))
	_draw_marker(rect)
	if piece != PT.Piece.NONE:
		# Dry pipe = brass/gold; wet = bright aqua, with a dark under-stroke and shine.
		var col := Color(0.10, 0.88, 0.92) if wet else Color(0.96, 0.64, 0.12)
		var c := Vector2(size, size) * 0.5
		var pipe_scale := 1.0 - _placement_pop * 0.24
		var w := maxf(3.0, size * 0.18) * pipe_scale
		for ch in CG.channels_for(piece, rot):
			for d in _DIRS:
				if ch & d:
					var end := c + _edge_off(d) * size * 0.5 * pipe_scale
					draw_line(c, end, Color(0.02, 0.09, 0.10, 0.8), w + maxf(2.0, size * 0.055))
					draw_line(c, end, col, w)
					draw_line(c, c + (end - c) * 0.8, Color(0.85, 1.0, 1.0, 0.65), maxf(1.0, w * 0.16))
		if _placement_pop > 0.0:
			draw_arc(c, size * (0.30 + _placement_pop * 0.16), 0.0, TAU, 24, Color(0.25, 0.95, 1.0, _placement_pop * 0.75), maxf(1.0, size * 0.035))
	_draw_port(rect)


# Inlet/outlet marker on the boundary edge: green triangle pointing INTO the cell (inlet, water
# enters) vs red triangle pointing OUT (outlet, water exits) — shape + color, colorblind-safe.
func _draw_port(rect: Rect2) -> void:
	if port == 0:
		return
	var col := Color(0.20, 0.90, 0.35) if port == 1 else Color(0.95, 0.30, 0.20)
	var c := rect.position + rect.size * 0.5
	var off := _edge_off(port_dir)
	var edge := c + off * (size * 0.5)
	var inward := edge - off * (size * 0.45)
	var perp := Vector2(-off.y, off.x) * (size * 0.22)
	var tri: PackedVector2Array
	if port == 1:  # inlet: apex points inward
		tri = PackedVector2Array([edge + perp, edge - perp, inward])
	else:  # outlet: apex points outward (toward the edge)
		tri = PackedVector2Array([inward + perp, inward - perp, edge])
	draw_colored_polygon(tri, col)


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
