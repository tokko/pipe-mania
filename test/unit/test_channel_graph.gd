extends "res://addons/gut/test.gd"
## S1.4 — channel-aware (cell, channel) connection graph. A cross is TWO disjoint
## channels (NS, EW) so no traversal can corner-cut through it.

const CG = preload("res://scripts/model/channel_graph.gd")
const PT = preload("res://scripts/model/pipe_types.gd")


## Hand-built pipe layout (duck-typed provider: pipe_at / pipe_rot_at / board).
class Layout:
	var board
	var _t := {}
	var _r := {}

	func _init(w: int, h: int) -> void:
		board = load("res://scripts/model/board.gd").new(w, h)

	func put(x: int, y: int, piece: int, rot: int = 0) -> void:
		_t[Vector2i(x, y)] = piece
		_r[Vector2i(x, y)] = rot

	func pipe_at(x: int, y: int) -> int:
		return _t.get(Vector2i(x, y), 0)  # 0 == Piece.NONE

	func pipe_rot_at(x: int, y: int) -> int:
		return _r.get(Vector2i(x, y), 0)


func _has(neigh: Array, x: int, y: int) -> bool:
	for nd in neigh:
		if nd[0] == x and nd[1] == y:
			return true
	return false


func test_channels_for_straight_single() -> void:
	assert_eq(CG.channels_for(PT.Piece.STRAIGHT, 0), [PT.N | PT.S])


func test_channels_for_cross_two_disjoint() -> void:
	var chs = CG.channels_for(PT.Piece.CROSS, 0)
	assert_eq(chs.size(), 2, "cross has two disjoint channels")
	assert_true(chs.has(PT.N | PT.S) and chs.has(PT.E | PT.W))


func test_channels_for_none_empty() -> void:
	assert_eq(CG.channels_for(PT.Piece.NONE, 0), [])


func test_channel_owning_edge_cross_splits_axes() -> void:
	assert_eq(CG.channel_owning_edge(PT.Piece.CROSS, 0, PT.N), 0)
	assert_eq(CG.channel_owning_edge(PT.Piece.CROSS, 0, PT.S), 0)
	assert_eq(CG.channel_owning_edge(PT.Piece.CROSS, 0, PT.E), 1)
	assert_eq(CG.channel_owning_edge(PT.Piece.CROSS, 0, PT.W), 1)


func test_channel_owning_edge_missing_is_negative() -> void:
	assert_eq(CG.channel_owning_edge(PT.Piece.STRAIGHT, 0, PT.N), 0)
	assert_eq(CG.channel_owning_edge(PT.Piece.STRAIGHT, 0, PT.E), -1, "straight rot0 has no E edge")


func test_link_two_vertical_straights() -> void:
	var L = Layout.new(3, 3)
	L.put(1, 0, PT.Piece.STRAIGHT, 0)
	L.put(1, 1, PT.Piece.STRAIGHT, 0)
	var link = CG.link_across(L, 1, 1, PT.N)
	assert_false(link.is_empty(), "vertical straights connect N<->S")
	assert_eq(link[1], 1)
	assert_eq(link[2], 0)


func test_no_link_when_edges_mismatch() -> void:
	var L = Layout.new(3, 3)
	L.put(1, 1, PT.Piece.STRAIGHT, 0)  # N|S, no E
	L.put(2, 1, PT.Piece.STRAIGHT, 0)  # N|S, no W
	assert_true(CG.link_across(L, 1, 1, PT.E).is_empty(), "vertical straights don't connect E-W")


func test_neighbors_vertical_line() -> void:
	var L = Layout.new(3, 3)
	L.put(1, 0, PT.Piece.STRAIGHT, 0)
	L.put(1, 1, PT.Piece.STRAIGHT, 0)
	L.put(1, 2, PT.Piece.STRAIGHT, 0)
	assert_eq(CG.neighbors(L, 1, 1, 0).size(), 2, "middle straight connects up and down")


func test_cross_no_corner_cut() -> void:  # FX_CROSS_CORNER (graph level)
	var L = Layout.new(3, 3)
	L.put(1, 1, PT.Piece.CROSS, 0)     # NS = channel 0, EW = channel 1
	L.put(1, 0, PT.Piece.STRAIGHT, 0)  # north neighbor (N|S)
	L.put(2, 1, PT.Piece.STRAIGHT, 1)  # east neighbor (E|W)
	var ns = CG.neighbors(L, 1, 1, 0)
	var ew = CG.neighbors(L, 1, 1, 1)
	assert_true(_has(ns, 1, 0), "NS channel connects north")
	assert_false(_has(ns, 2, 1), "NS channel does NOT reach east — no corner-cut")
	assert_true(_has(ew, 2, 1), "EW channel connects east")
	assert_false(_has(ew, 1, 0), "EW channel does NOT reach north — no corner-cut")


func test_cross_no_corner_cut_south_west() -> void:  # symmetric coverage
	var L = Layout.new(3, 3)
	L.put(1, 1, PT.Piece.CROSS, 0)
	L.put(1, 2, PT.Piece.STRAIGHT, 0)  # south (N|S)
	L.put(0, 1, PT.Piece.STRAIGHT, 1)  # west  (E|W)
	var ns = CG.neighbors(L, 1, 1, 0)
	var ew = CG.neighbors(L, 1, 1, 1)
	assert_true(_has(ns, 1, 2), "NS channel connects south")
	assert_false(_has(ns, 0, 1), "NS channel does NOT reach west")
	assert_true(_has(ew, 0, 1), "EW channel connects west")
	assert_false(_has(ew, 1, 2), "EW channel does NOT reach south")


func test_cross_adjacent_cross_channels_stay_disjoint() -> void:
	var L = Layout.new(3, 3)
	L.put(1, 1, PT.Piece.CROSS, 0)
	L.put(2, 1, PT.Piece.CROSS, 0)
	assert_true(_has(CG.neighbors(L, 1, 1, 1), 2, 1), "EW links two adjacent crosses")
	assert_false(_has(CG.neighbors(L, 1, 1, 0), 2, 1), "NS of left cross never reaches the right cross")
