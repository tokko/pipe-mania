extends RefCounted
## Seeded, forced piece queue. The player cannot pick, skip, OR rotate — the deck
## hands out each piece pre-oriented (classic Pipe Mania); only the current piece
## (and a preview of upcoming types) is exposed; advance() consumes it. Infinite:
## pieces are rolled on demand from weighted types. No Node deps.

const PT = preload("res://scripts/model/pipe_types.gd")

# A recently-dealt TYPE is temporarily less likely, so the same piece rarely shows up
# three-plus times running. Light touch: each appearance in the last _RECENCY_WINDOW rolls
# scales that type's weight by _RECENCY_DECAY — a variety nudge, not forced alternation.
const _RECENCY_WINDOW := 2
const _RECENCY_DECAY := 0.5

var _rng: RandomNumberGenerator
var _weights: Dictionary
var _recent: Array  # last few rolled types (newest last), for the recency decay
var _buffer: Array  # upcoming Vector2i(type, rot); _buffer[0] is current


func _init(seed_: int, weights: Dictionary = {}) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_
	_weights = weights if not weights.is_empty() else {
		PT.Piece.STRAIGHT: 40, PT.Piece.BEND: 40, PT.Piece.CROSS: 20,
	}
	_recent = []
	_buffer = []


func current() -> int:
	_ensure(1)
	return _buffer[0].x


## The orientation the deck rolled for the current piece — placement stamps this
## (the player never rotates; the deck owns orientation).
func current_rot() -> int:
	_ensure(1)
	return _buffer[0].y


## The next n upcoming piece TYPES (after current), for the HUD preview glyphs.
func preview(n: int) -> Array:
	_ensure(n + 1)
	var out: Array = []
	for v in _buffer.slice(1, n + 1):
		out.append(v.x)
	return out


func advance() -> void:
	_ensure(1)
	_buffer.pop_front()


func _ensure(n: int) -> void:
	while _buffer.size() < n:
		_buffer.append(_roll())


func _roll() -> Vector2i:
	var weighted := {}
	var total := 0.0
	for p in _weights:
		var w: float = _weights[p] * pow(_RECENCY_DECAY, _recent.count(p))  # decay recent types
		weighted[p] = w
		total += w
	var r := _rng.randf() * total
	var acc := 0.0
	var piece: int = PT.Piece.STRAIGHT
	for p in weighted:
		acc += weighted[p]
		if r <= acc:
			piece = p
			break
	_recent.append(piece)
	if _recent.size() > _RECENCY_WINDOW:
		_recent.pop_front()
	var rot := _rng.randi_range(0, 3)
	return Vector2i(piece, rot)
