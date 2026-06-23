extends RefCounted
## Seeded, forced piece queue. The player cannot pick or skip — only the current
## piece (and a preview of upcoming pieces) is exposed; advance() consumes it.
## Infinite: pieces are rolled on demand from weighted types. No Node deps.

const PT = preload("res://scripts/model/pipe_types.gd")

var _rng: RandomNumberGenerator
var _weights: Dictionary
var _buffer: Array  # upcoming piece types; _buffer[0] is current


func _init(seed_: int, weights: Dictionary = {}) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_
	_weights = weights if not weights.is_empty() else {
		PT.Piece.STRAIGHT: 40, PT.Piece.BEND: 40, PT.Piece.CROSS: 20,
	}
	_buffer = []


func current() -> int:
	_ensure(1)
	return _buffer[0]


## The next n upcoming pieces (after current).
func preview(n: int) -> Array:
	_ensure(n + 1)
	return _buffer.slice(1, n + 1)


func advance() -> void:
	_ensure(1)
	_buffer.pop_front()


func _ensure(n: int) -> void:
	while _buffer.size() < n:
		_buffer.append(_roll())


func _roll() -> int:
	var total := 0
	for w in _weights.values():
		total += w
	var r := _rng.randi_range(1, total)
	var acc := 0
	for piece in _weights:
		acc += _weights[piece]
		if r <= acc:
			return piece
	return PT.Piece.STRAIGHT
