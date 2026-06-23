extends RefCounted
## Pure game-round state: owns a Board, the forced piece queue, the placed-pipe
## grid, and the build/flow phase. No Node deps — the View calls go()/place() on
## input and step() (S1.5) on a timer; tests call them directly.

const Board = preload("res://scripts/model/board.gd")
const PT = preload("res://scripts/model/pipe_types.gd")
const PieceQueue = preload("res://scripts/model/piece_queue.gd")

enum Phase { BUILD, FLOW }

var board: Board
var queue: PieceQueue
var phase: int = Phase.BUILD

var _ptype: PackedInt32Array  # placed piece type per cell (0 == Piece.NONE)
var _prot: PackedInt32Array   # placed rotation per cell
var _wet: PackedByteArray     # 1 == water has reached this cell (set by flow, S1.5)


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
	phase = Phase.FLOW


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
