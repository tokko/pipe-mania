extends RefCounted
## Seeded board generator. Produces a Board with inlet on the left edge and
## outlet on the right edge, hazards scattered in the interior, and a guaranteed
## bomb-safe inlet->outlet corridor (cell-level BFS). If a request is infeasible
## it reduces hazard density until solvable. No Node deps — headless-testable.
##
## Scope note: this proves a *corridor* exists, not that the forced piece queue
## can realize it (accepted MVP scope-risk; see docs/ROADMAP.md S1.2).

const PT = preload("res://scripts/model/pipe_types.gd")
const Board = preload("res://scripts/model/board.gd")

const MAX_RETRIES := 50
const _NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func generate(seed_: int, w: int, h: int, bombs: int, blocked: int) -> Board:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var b := bombs
	var k := blocked
	while true:
		for attempt in MAX_RETRIES:
			var board := _attempt(rng, w, h, b, k)
			if is_solvable(board):
				return board
		# Infeasible at this density: relax and retry (0 hazards is always solvable).
		if b > 0:
			b -= 1
		elif k > 0:
			k -= 1
		else:
			return _attempt(rng, w, h, 0, 0)
	return null  # unreachable


static func _attempt(rng: RandomNumberGenerator, w: int, h: int, bombs: int, blocked: int) -> Board:
	var board := Board.new(w, h)
	board.set_inlet(Vector2i(0, rng.randi_range(0, h - 1)), PT.E)
	board.set_outlet(Vector2i(w - 1, rng.randi_range(0, h - 1)), PT.W)

	var cells := []
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if p != board.inlet_pos and p != board.outlet_pos:
				cells.append(p)
	_shuffle(cells, rng)

	var i := 0
	for _b in bombs:
		if i < cells.size():
			board.set_cell(cells[i].x, cells[i].y, PT.Cell.BOMB)
			i += 1
	for _k in blocked:
		if i < cells.size():
			board.set_cell(cells[i].x, cells[i].y, PT.Cell.BLOCKED)
			i += 1
	return board


## A bomb-safe inlet->outlet corridor exists (cell-level BFS over passable cells).
static func is_solvable(board: Board) -> bool:
	if not _passable(board, board.inlet_pos) or not _passable(board, board.outlet_pos):
		return false
	var seen := {board.inlet_pos: true}
	var frontier := [board.inlet_pos]
	while not frontier.is_empty():
		var p = frontier.pop_back()
		if p == board.outlet_pos:
			return true
		for d in _NEIGHBORS:
			var np: Vector2i = p + d
			if board.in_bounds(np.x, np.y) and not seen.has(np) and _passable(board, np):
				seen[np] = true
				frontier.append(np)
	return false


## Passable = OPEN and not orthogonally adjacent to a bomb (water touching a bomb fails).
static func _passable(board: Board, p: Vector2i) -> bool:
	if board.cell_at(p.x, p.y) != PT.Cell.OPEN:
		return false
	for d in _NEIGHBORS:
		var np: Vector2i = p + d
		if board.in_bounds(np.x, np.y) and board.cell_at(np.x, np.y) == PT.Cell.BOMB:
			return false
	return true


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
