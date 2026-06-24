extends "res://addons/gut/test.gd"
## S1.6 — shortest inlet->outlet route length over the channel graph.
## score() = wet-graph route (cells), 0 if unconnected. dry_route_length() = same
## over placed (dry) pipe for the live build readout. BFS finds the SHORTEST route,
## so it is shortcut-collapse-correct once branching (t-junctions, post-MVP) exists.

const Board = preload("res://scripts/model/board.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const PT = preload("res://scripts/model/pipe_types.gd")


func _resolve(gs) -> void:
	gs.go()
	gs.resolve()


func test_score_straight_line_is_cell_count() -> void:  # FX_STRAIGHT8
	var b = Board.new(8, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(7, 0), PT.E)
	var gs = GameState.new(b)
	for x in 8:
		gs.set_pipe(x, 0, PT.Piece.STRAIGHT, 1)
	_resolve(gs)
	assert_eq(gs.score(), 8, "an 8-cell connecting line scores 8")


func test_longer_winding_path_scores_its_length() -> void:  # "longer wins"
	# 7-cell U: (0,2)->(0,1)->(0,0)->(1,0)->(2,0)->(2,1)->(2,2)
	var b = Board.new(3, 3)
	b.set_inlet(Vector2i(0, 2), PT.W)
	b.set_outlet(Vector2i(2, 2), PT.E)
	var gs = GameState.new(b)
	gs.set_pipe(0, 2, PT.Piece.BEND, 3)      # W|N
	gs.set_pipe(0, 1, PT.Piece.STRAIGHT, 0)  # N|S
	gs.set_pipe(0, 0, PT.Piece.BEND, 1)      # E|S
	gs.set_pipe(1, 0, PT.Piece.STRAIGHT, 1)  # E|W
	gs.set_pipe(2, 0, PT.Piece.BEND, 2)      # S|W
	gs.set_pipe(2, 1, PT.Piece.STRAIGHT, 0)  # N|S
	gs.set_pipe(2, 2, PT.Piece.BEND, 0)      # N|E
	_resolve(gs)
	assert_eq(gs.score(), 7, "the winding 7-cell route scores 7 (longer wins)")


func test_score_zero_when_unconnected() -> void:
	var b = Board.new(3, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(2, 0), PT.E)
	var gs = GameState.new(b)
	gs.set_pipe(0, 0, PT.Piece.STRAIGHT, 1)  # dangling, never reaches outlet
	_resolve(gs)
	assert_eq(gs.score(), 0, "an unconnected board scores 0")


func test_cross_corner_scores_zero() -> void:  # FX_CROSS_CORNER (scoring level)
	var b = Board.new(2, 2)
	b.set_inlet(Vector2i(0, 1), PT.W)
	b.set_outlet(Vector2i(1, 0), PT.N)
	var gs = GameState.new(b)
	gs.set_pipe(0, 1, PT.Piece.STRAIGHT, 1)  # E|W -> feeds (1,1) from the west
	gs.set_pipe(1, 1, PT.Piece.CROSS, 0)     # corner: would need W->N, but channels are disjoint
	gs.set_pipe(1, 0, PT.Piece.STRAIGHT, 0)  # N|S, N = outlet drain
	_resolve(gs)
	assert_eq(gs.score(), 0, "BFS cannot corner-cut a cross — no route, score 0")


func test_cross_corner_control_bend_connects() -> void:  # control
	var b = Board.new(2, 2)
	b.set_inlet(Vector2i(0, 1), PT.W)
	b.set_outlet(Vector2i(1, 0), PT.N)
	var gs = GameState.new(b)
	gs.set_pipe(0, 1, PT.Piece.STRAIGHT, 1)
	gs.set_pipe(1, 1, PT.Piece.BEND, 3)      # W|N — DOES turn the corner
	gs.set_pipe(1, 0, PT.Piece.STRAIGHT, 0)
	_resolve(gs)
	assert_eq(gs.score(), 3, "a bend turns the corner -> 3-cell route")


func test_score_route_cells_match_line() -> void:  # S3.1
	var b = Board.new(8, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(7, 0), PT.E)
	var gs = GameState.new(b)
	for x in 8:
		gs.set_pipe(x, 0, PT.Piece.STRAIGHT, 1)
	_resolve(gs)
	var route = gs.score_route()
	assert_eq(route.size(), 8, "route has 8 cells")
	assert_eq(route.size(), gs.score(), "route size == score on MVP single-channel")
	assert_eq(route[0], Vector2i(0, 0))
	assert_eq(route[7], Vector2i(7, 0))


func test_score_route_empty_when_unconnected() -> void:  # S3.1
	var b = Board.new(3, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(2, 0), PT.E)
	var gs = GameState.new(b)
	gs.set_pipe(0, 0, PT.Piece.STRAIGHT, 1)  # dangling
	_resolve(gs)
	assert_eq(gs.score_route(), [], "unconnected -> empty route")


func test_dry_route_length_before_flow() -> void:
	var b = Board.new(5, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	b.set_outlet(Vector2i(4, 0), PT.E)
	var gs = GameState.new(b)
	for x in 5:
		gs.set_pipe(x, 0, PT.Piece.STRAIGHT, 1)
	assert_eq(gs.dry_route_length(), 5, "dry readout = placed route length before flow")
	assert_eq(gs.score(), 0, "score is 0 before flow wets anything")
