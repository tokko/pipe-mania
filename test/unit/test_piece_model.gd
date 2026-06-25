extends "res://addons/gut/test.gd"
## S1.3 — piece edge model + seeded forced piece queue.

const PT = preload("res://scripts/model/pipe_types.gd")
const PieceQueue = preload("res://scripts/model/piece_queue.gd")


func test_none_is_zero() -> void:
	assert_eq(PT.Piece.NONE, 0, "NONE must be 0 (zero-filled pipe grid contract)")
	assert_eq(PT.piece_edges(PT.Piece.NONE, 0), 0)


func test_straight_edges() -> void:
	assert_eq(PT.piece_edges(PT.Piece.STRAIGHT, 0), PT.N | PT.S)
	assert_eq(PT.piece_edges(PT.Piece.STRAIGHT, 1), PT.E | PT.W)
	assert_eq(PT.piece_edges(PT.Piece.STRAIGHT, 2), PT.N | PT.S, "2-fold symmetric")


func test_bend_edges() -> void:
	assert_eq(PT.piece_edges(PT.Piece.BEND, 0), PT.N | PT.E)
	assert_eq(PT.piece_edges(PT.Piece.BEND, 1), PT.E | PT.S)
	assert_eq(PT.piece_edges(PT.Piece.BEND, 2), PT.S | PT.W)
	assert_eq(PT.piece_edges(PT.Piece.BEND, 3), PT.W | PT.N)


func test_cross_edges() -> void:
	assert_eq(PT.piece_edges(PT.Piece.CROSS, 0), PT.N | PT.E | PT.S | PT.W)


func test_queue_deterministic_same_seed() -> void:
	var a = PieceQueue.new(123)
	var b = PieceQueue.new(123)
	for i in 12:
		assert_eq(a.current(), b.current(), "same seed -> same sequence")
		a.advance()
		b.advance()


func test_queue_current_never_none() -> void:
	var q = PieceQueue.new(5)
	for i in 20:
		var c = q.current()
		assert_true(c == PT.Piece.STRAIGHT or c == PT.Piece.BEND or c == PT.Piece.CROSS,
			"queue yields a valid forced piece, never NONE")
		q.advance()


func test_preview_matches_future_currents() -> void:
	var q = PieceQueue.new(9)
	var prev = q.preview(5)
	assert_eq(prev.size(), 5, "preview returns n upcoming pieces")
	q.advance()
	assert_eq(q.current(), prev[0], "preview[0] becomes current after one advance")


func test_deck_rolls_varied_orientations() -> void:  # the deck owns rotation (classic Pipe Mania)
	var q = PieceQueue.new(7)
	var seen := {}
	for i in 24:
		seen[q.current_rot()] = true
		q.advance()
	assert_gt(seen.size(), 1, "deck deals more than one orientation across pieces")


func test_recency_decay_reduces_repeats() -> void:  # variety nudge: no 3-straights-in-a-row spam
	var q = PieceQueue.new(99)
	var prev := -1
	var straight_prev := 0
	var straight_then_straight := 0
	for i in 4000:
		var c = q.current()
		if prev == PT.Piece.STRAIGHT:
			straight_prev += 1
			if c == PT.Piece.STRAIGHT:
				straight_then_straight += 1
		prev = c
		q.advance()
	var repeat_rate := float(straight_then_straight) / maxi(1, straight_prev)
	# Raw weight (40/100) would repeat ~0.40 of the time; the recency decay pulls it well below.
	assert_lt(repeat_rate, 0.35, "a just-dealt type repeats less often than its raw weight implies")
