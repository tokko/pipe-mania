extends RefCounted
## Pure game-round state: owns a Board and the build/flow phase. No Node deps.
## The View calls go() (and later step()) on a timer; tests call them directly.

enum Phase { BUILD, FLOW }

var board
var phase: int = Phase.BUILD


func _init(board_) -> void:
	board = board_


## Lock the build and start the verify flow. Idempotent once flowing.
func go() -> void:
	phase = Phase.FLOW
