extends RefCounted
## Channel-aware connection graph. A node is a (cell, channel) pair. Straight/bend
## pieces have one channel (all their open edges); a CROSS has TWO disjoint channels
## (N<->S and E<->W) that never link to each other — so no flow or BFS traversal can
## corner-cut through a cross. step() (S1.5) and the scoring BFS (S1.6) both walk this
## same graph via neighbors().
##
## Operates on any duck-typed provider exposing: pipe_at(x,y), pipe_rot_at(x,y), board.

const PT = preload("res://scripts/model/pipe_types.gd")

const _DIRS := [PT.N, PT.E, PT.S, PT.W]


static func _delta(d: int) -> Vector2i:
	match d:
		PT.N: return Vector2i(0, -1)
		PT.S: return Vector2i(0, 1)
		PT.E: return Vector2i(1, 0)
		PT.W: return Vector2i(-1, 0)
	return Vector2i.ZERO


## Channel edge-masks for a placed piece. CROSS -> two channels; NONE -> none; else one.
static func channels_for(piece: int, rot: int) -> Array:
	if piece == PT.Piece.CROSS:
		return [PT.N | PT.S, PT.E | PT.W]
	if piece == PT.Piece.NONE:
		return []
	return [PT.piece_edges(piece, rot)]


## Index of the channel that owns edge d, or -1 if the piece has no such edge.
static func channel_owning_edge(piece: int, rot: int, d: int) -> int:
	var chs := channels_for(piece, rot)
	for i in chs.size():
		if chs[i] & d:
			return i
	return -1


## If (ax,ay)'s pipe links to its neighbor across edge d, returns
## [chA, nx, ny, chB]; otherwise []. A link requires both pipes to expose the
## matching edge AND for those edges to belong to a channel on each side.
static func link_across(provider, ax: int, ay: int, d: int) -> Array:
	var pa: int = provider.pipe_at(ax, ay)
	if pa == PT.Piece.NONE:
		return []
	var ch_a := channel_owning_edge(pa, provider.pipe_rot_at(ax, ay), d)
	if ch_a < 0:
		return []
	var delta := _delta(d)
	var nx := ax + delta.x
	var ny := ay + delta.y
	if not provider.board.in_bounds(nx, ny):
		return []
	var pb: int = provider.pipe_at(nx, ny)
	if pb == PT.Piece.NONE:
		return []
	var ch_b := channel_owning_edge(pb, provider.pipe_rot_at(nx, ny), PT.opposite(d))
	if ch_b < 0:
		return []
	return [ch_a, nx, ny, ch_b]


## Connected neighbour nodes of (x,y,channel): an array of [nx, ny, nch].
static func neighbors(provider, x: int, y: int, channel: int) -> Array:
	var p: int = provider.pipe_at(x, y)
	if p == PT.Piece.NONE:
		return []
	var chs := channels_for(p, provider.pipe_rot_at(x, y))
	if channel < 0 or channel >= chs.size():
		return []
	var mask: int = chs[channel]
	var out := []
	for d in _DIRS:
		if mask & d:
			var link := link_across(provider, x, y, d)
			if not link.is_empty() and link[0] == channel:
				out.append([link[1], link[2], link[3]])
	return out
