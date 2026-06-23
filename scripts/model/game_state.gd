extends RefCounted
## Pure game-round state: owns a Board and the build/flow phase. No Node deps.
## The View calls go() (and later step()) on a timer; tests call them directly.

const Board = preload("res://scripts/model/board.gd")

enum Phase { BUILD, FLOW }

var board: Board
var phase: int = Phase.BUILD


func _init(board_: Board) -> void:
	board = board_


## Lock the build and start the verify flow. Idempotent once flowing.
func go() -> void:
	phase = Phase.FLOW
