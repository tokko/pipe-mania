extends "res://addons/gut/test.gd"
## S2.1 — grid_layout: pure cell<->pixel math + the min-cell floor. The headless,
## gate-meaningful core of the view (rendering itself is integration/screenshot-gated).

const GridLayout = preload("res://scripts/view/grid_layout.gd")

const VIEW := Vector2i(720, 1280)
const MIN_CELL := 44


func test_cell_to_pixel_pixel_to_cell_round_trip() -> void:
	var gl = GridLayout.new(9, 13, VIEW, MIN_CELL, 0)
	for y in 13:
		for x in 9:
			var center: Vector2 = gl.cell_to_pixel(x, y) + Vector2(gl.cell_size, gl.cell_size) * 0.5
			assert_eq(gl.pixel_to_cell(center), Vector2i(x, y), "round-trip at (%d,%d)" % [x, y])


func test_cells_meet_floor_at_real_cap() -> void:  # positive liveness
	# 720x1280, 9x13 cap -> natural fit ~80px, comfortably >= 44.
	var gl = GridLayout.new(9, 13, VIEW, MIN_CELL, 0)
	assert_gte(gl.cell_size, MIN_CELL, "cells stay >= MIN_CELL at the real cap")


func test_floor_engages_on_tiny_viewport() -> void:  # the REAL failing-able control
	# A deliberately tiny viewport: natural fit < MIN_CELL, so the floor must clamp UP.
	var gl = GridLayout.new(9, 13, Vector2i(320, 320), MIN_CELL, 0)
	var natural := mini(320 / 9, 320 / 13)  # ~24, below the floor
	assert_lt(natural, MIN_CELL, "precondition: this viewport's natural fit is below the floor")
	assert_eq(gl.cell_size, MIN_CELL, "floor clamps cell_size UP to MIN_CELL (board overflows -> pan)")


func test_origin_centers_board() -> void:
	var gl = GridLayout.new(4, 4, VIEW, MIN_CELL, 0)
	var board_w: float = gl.cell_size * 4
	assert_almost_eq(gl.origin.x, (VIEW.x - board_w) / 2.0, 0.5, "board horizontally centered")
