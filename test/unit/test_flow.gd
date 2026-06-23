extends "res://addons/gut/test.gd"
## S1.5a — deterministic flow step() over the channel graph. Water seeds from the
## inlet's boundary-edge channel and advances one ring per step(). Visited state is
## channel-granular (a cross's NS-wet must NOT alias its EW channel).
##
## Convention: inlet_dir / outlet_dir = the cell's boundary edge (W for a left inlet,
## E for a right outlet). The inlet pipe must expose inlet_dir to be seeded.

const Board = preload("res://scripts/model/board.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const PT = preload("res://scripts/model/pipe_types.gd")


func _settle(gs, max_steps := 50) -> void:
	var n := 0
	while gs.step() and n < max_steps:
		n += 1


func test_flow_propagates_horizontal_line() -> void:
	var b = Board.new(5, 3)
	b.set_inlet(Vector2i(0, 1), PT.W)
	b.set_outlet(Vector2i(4, 1), PT.E)
	var gs = GameState.new(b)
	for x in 5:
		gs.set_pipe(x, 1, PT.Piece.STRAIGHT, 1)  # E|W
	gs.go()
	_settle(gs)
	for x in 5:
		assert_true(gs.is_wet(x, 1), "cell (%d,1) should be wet" % x)
	assert_false(gs.is_wet(2, 0), "off-path cell stays dry")


func test_step_returns_false_when_settled() -> void:
	var b = Board.new(3, 1)
	b.set_inlet(Vector2i(0, 0), PT.W)
	var gs = GameState.new(b)
	for x in 3:
		gs.set_pipe(x, 0, PT.Piece.STRAIGHT, 1)
	gs.go()
	_settle(gs)
	assert_false(gs.step(), "flow has settled — no further advance")


func test_cross_channel_not_aliased() -> void:  # the S1.4-reflection directive control
	var b = Board.new(3, 3)
	b.set_inlet(Vector2i(1, 0), PT.N)
	var gs = GameState.new(b)
	gs.set_pipe(1, 0, PT.Piece.STRAIGHT, 0)  # N|S
	gs.set_pipe(1, 1, PT.Piece.CROSS, 0)     # NS=ch0, EW=ch1
	gs.set_pipe(1, 2, PT.Piece.STRAIGHT, 0)  # N|S
	gs.set_pipe(2, 1, PT.Piece.STRAIGHT, 1)  # E|W on the EW side, NOT fed
	gs.go()
	_settle(gs)
	assert_true(gs.is_node_wet(1, 1, 0), "cross NS channel is wet")
	assert_false(gs.is_node_wet(1, 1, 1), "cross EW channel stays DRY (no aliasing)")
	assert_false(gs.is_wet(2, 1), "isolated EW-side pipe stays dry")
	assert_true(gs.is_wet(1, 2), "NS flow continues downward")


func test_no_seed_without_inlet_pipe() -> void:
	var b = Board.new(3, 3)
	b.set_inlet(Vector2i(0, 1), PT.W)
	var gs = GameState.new(b)
	gs.go()
	assert_false(gs.step(), "no pipe at inlet -> no flow")
	assert_false(gs.is_wet(0, 1))


func test_seed_requires_inlet_edge() -> void:
	var b = Board.new(3, 3)
	b.set_inlet(Vector2i(0, 1), PT.W)
	var gs = GameState.new(b)
	gs.set_pipe(0, 1, PT.Piece.STRAIGHT, 0)  # N|S — does not expose W
	gs.go()
	assert_false(gs.is_wet(0, 1), "inlet pipe lacking the inlet edge isn't seeded")
