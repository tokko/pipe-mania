extends RefCounted
## Pure game-round state: owns a Board, the forced piece queue, the placed-pipe
## grid, and the build/flow phase. No Node deps — the View calls go()/place() on
## input and step() (S1.5) on a timer; tests call them directly.

const Board = preload("res://scripts/model/board.gd")
const PT = preload("res://scripts/model/pipe_types.gd")
const PieceQueue = preload("res://scripts/model/piece_queue.gd")
const CG = preload("res://scripts/model/channel_graph.gd")

enum Phase { BUILD, FLOW }
## Round result, distinct from Phase. NONE = undecided (still flowing / closed loop).
enum Outcome { NONE, CLEARED, BOMB, LEAK }

var board: Board
var queue: PieceQueue
var phase: int = Phase.BUILD

var _ptype: PackedInt32Array  # placed piece type per cell (0 == Piece.NONE)
var _prot: PackedInt32Array   # placed rotation per cell
var _wet: PackedByteArray     # 1 == any channel of this cell is wet (rendering/overwrite)

# Channel-granular flow state (a cross's NS and EW are separate nodes — no aliasing).
var _wet_nodes: Dictionary = {}  # Vector3i(x, y, channel) -> true
var _frontier: Array = []        # Vector3i nodes wetted on the last step()


func _init(board_: Board, queue_: PieceQueue = null) -> void:
	board = board_
	queue = queue_ if queue_ != null else PieceQueue.new(0)
	var n := board.width * board.height
	_ptype = PackedInt32Array()
	_ptype.resize(n)
	_prot = PackedInt32Array()
	_prot.resize(n)
	_wet = PackedByteArray()
	_wet.resize(n)


## Lock the build and start the verify flow. Idempotent once flowing.
func go() -> void:
	if phase == Phase.FLOW:
		return
	phase = Phase.FLOW
	_begin_flow()


## Directly set a cell's pipe, bypassing placement rules. For fixtures/tests and
## scripted proof scenes — NOT the player path (use place() for that).
func set_pipe(x: int, y: int, piece: int, rot: int = 0) -> void:
	var idx := y * board.width + x
	_ptype[idx] = piece
	_prot[idx] = rot & 3


func is_node_wet(x: int, y: int, channel: int) -> bool:
	return _wet_nodes.has(Vector3i(x, y, channel))


const _NO_NODE := Vector3i(-1, -1, -1)


## Cells on the shortest inlet->outlet route over the WET graph; 0 if unconnected.
## BFS finds the shortest route, so it collapses to the short side of any shortcut
## (shortcuts need branching / t-junctions — post-MVP — but the rule is already correct).
func score() -> int:
	return _shortest_path(true).size()


## Same over PLACED (dry) pipe — feeds E2's live build readout. 0 if not yet connected.
func dry_route_length() -> int:
	return _shortest_path(false).size()


## The cells on the shortest WET inlet->outlet route (for the scored-route highlight); [] if
## unconnected. On MVP single-channel routes size() == score(); a cell could repeat only if a
## route re-entered it on a second channel (needs branching / t-junctions, deferred).
func score_route() -> Array:
	var cells: Array = []
	for node in _shortest_path(true):
		cells.append(Vector2i(node.x, node.y))
	return cells


func _node_at(pos: Vector2i, dir: int) -> Vector3i:
	if not board.in_bounds(pos.x, pos.y):
		return _NO_NODE
	var piece := pipe_at(pos.x, pos.y)
	if piece == PT.Piece.NONE:
		return _NO_NODE
	var ch := CG.channel_owning_edge(piece, pipe_rot_at(pos.x, pos.y), dir)
	return _NO_NODE if ch < 0 else Vector3i(pos.x, pos.y, ch)


# BFS shortest inlet->outlet path as a node list [start..goal]; [] if unreachable.
# wet_only restricts to wet nodes. score()/score_route() derive from this.
func _shortest_path(wet_only: bool) -> Array:
	var start := _node_at(board.inlet_pos, board.inlet_dir)
	var goal := _node_at(board.outlet_pos, board.outlet_dir)
	if start == _NO_NODE or goal == _NO_NODE:
		return []
	if wet_only and not _wet_nodes.has(start):
		return []
	var prev := {start: start}  # node -> predecessor; start maps to itself (sentinel)
	var bfs: Array = [start]
	var head := 0
	while head < bfs.size():
		var node: Vector3i = bfs[head]
		head += 1
		if node == goal:
			var path: Array = []
			var cur: Vector3i = goal
			while cur != prev[cur]:
				path.append(cur)
				cur = prev[cur]
			path.append(start)
			path.reverse()
			return path
		for nb in CG.neighbors(self, node.x, node.y, node.z):
			var key := Vector3i(nb[0], nb[1], nb[2])
			if wet_only and not _wet_nodes.has(key):
				continue
			if prev.has(key):
				continue
			prev[key] = node
			bfs.append(key)
	return []


## The outlet pipe's channel that owns the outlet drain edge is wet.
func is_cleared() -> bool:
	var op := board.outlet_pos
	if not board.in_bounds(op.x, op.y):
		return false
	var piece := pipe_at(op.x, op.y)
	if piece == PT.Piece.NONE:
		return false
	var ch := CG.channel_owning_edge(piece, pipe_rot_at(op.x, op.y), board.outlet_dir)
	return ch >= 0 and is_node_wet(op.x, op.y, ch)


## Any wet cell is orthogonally adjacent to a bomb.
func is_bombed() -> bool:
	for node in _wet_nodes:
		for off in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nx: int = node.x + off.x
			var ny: int = node.y + off.y
			if board.in_bounds(nx, ny) and board.cell_at(nx, ny) == PT.Cell.BOMB:
				return true
	return false


## Step the flow to a terminal outcome, checked each ring as CLEARED > BOMB > LEAK
## (so reaching the outlet beats bomb-adjacency on the same step). Assumes go().
## The seed ring is checked first (before any step) — intentional: if the inlet cell
## is itself bomb-adjacent or already complete, that resolves immediately.
func resolve() -> int:
	var o := outcome_now()
	while o == Outcome.NONE and step():
		o = outcome_now()
	return o


## Terminal outcome at the CURRENT wet state (CLEARED > BOMB > LEAK), or NONE if still
## resolvable. Public so the FlowAnimator can poll it each tick.
func outcome_now() -> int:
	if is_cleared():
		return Outcome.CLEARED
	if is_bombed():
		return Outcome.BOMB
	if is_leaking():
		return Outcome.LEAK
	return Outcome.NONE


## A wet channel exposes an open edge that neither connects to a neighbour pipe nor
## is the inlet source / outlet drain edge → water spills (leak).
func is_leaking() -> bool:
	for node in _wet_nodes:
		var chs := CG.channels_for(pipe_at(node.x, node.y), pipe_rot_at(node.x, node.y))
		if node.z >= chs.size():
			continue
		var mask: int = chs[node.z]
		for d in [PT.N, PT.E, PT.S, PT.W]:
			if not (mask & d):
				continue
			if not CG.link_across(self, node.x, node.y, d).is_empty():
				continue  # connects onward — no spill
			if node.x == board.inlet_pos.x and node.y == board.inlet_pos.y and d == board.inlet_dir:
				continue  # inlet source edge
			if node.x == board.outlet_pos.x and node.y == board.outlet_pos.y and d == board.outlet_dir:
				continue  # outlet drain edge
			return true
	return false


## Advance the wavefront one ring. Returns true if any new node became wet.
func step() -> bool:
	var next: Array = []
	for node in _frontier:
		for nb in CG.neighbors(self, node.x, node.y, node.z):
			var key := Vector3i(nb[0], nb[1], nb[2])
			if not _wet_nodes.has(key):
				_wet_nodes[key] = true
				_wet[nb[1] * board.width + nb[0]] = 1
				next.append(key)
	_frontier = next
	return not next.is_empty()


# Seed the inlet channel that owns the inlet boundary edge (if the pipe exposes it).
func _begin_flow() -> void:
	_wet_nodes.clear()
	_frontier.clear()
	var ip := board.inlet_pos
	if not board.in_bounds(ip.x, ip.y):
		return
	var piece := pipe_at(ip.x, ip.y)
	if piece == PT.Piece.NONE:
		return
	var ch := CG.channel_owning_edge(piece, pipe_rot_at(ip.x, ip.y), board.inlet_dir)
	if ch < 0:
		return
	var key := Vector3i(ip.x, ip.y, ch)
	_wet_nodes[key] = true
	_wet[ip.y * board.width + ip.x] = 1
	_frontier = [key]


func current_piece() -> int:
	return queue.current()


func preview(n: int) -> Array:
	return queue.preview(n)


func pipe_at(x: int, y: int) -> int:
	return _ptype[y * board.width + x]


func pipe_rot_at(x: int, y: int) -> int:
	return _prot[y * board.width + x]


func is_wet(x: int, y: int) -> bool:
	return _wet[y * board.width + x] != 0


# Cell-level wet flag only (drives rendering + the wet-overwrite rule). Flow seeding
# uses the channel-granular _wet_nodes — this does NOT make is_node_wet/score see water.
func mark_wet(x: int, y: int) -> void:
	_wet[y * board.width + x] = 1


## Place the current (forced) piece at (x,y) with rotation. Returns true on success.
## Rejected outside BUILD, off an OPEN cell, or onto already-wet pipe. Dry pipe may
## be freely overwritten.
func place(x: int, y: int, rotation: int = 0) -> bool:
	if phase != Phase.BUILD:
		return false
	if not board.in_bounds(x, y):
		return false
	if board.cell_at(x, y) != PT.Cell.OPEN:
		return false
	var idx := y * board.width + x
	if _wet[idx] != 0:
		return false
	_ptype[idx] = queue.current()
	_prot[idx] = rotation & 3
	queue.advance()
	return true
