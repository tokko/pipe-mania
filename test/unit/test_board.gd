extends "res://addons/gut/test.gd"
## S1.1 — Board model: grid of cell types + inlet/outlet with fixed edge dirs.

const Board = preload("res://scripts/model/board.gd")
const PT = preload("res://scripts/model/pipe_types.gd")


func test_dimensions_and_default_open() -> void:
	var b = Board.new(5, 7)
	assert_eq(b.width, 5)
	assert_eq(b.height, 7)
	assert_eq(b.cell_at(0, 0), PT.Cell.OPEN, "cells default to OPEN")
	assert_eq(b.cell_at(4, 6), PT.Cell.OPEN)


func test_set_and_get_cell_type() -> void:
	var b = Board.new(3, 3)
	b.set_cell(1, 1, PT.Cell.BOMB)
	b.set_cell(2, 0, PT.Cell.BLOCKED)
	assert_eq(b.cell_at(1, 1), PT.Cell.BOMB)
	assert_eq(b.cell_at(2, 0), PT.Cell.BLOCKED)
	assert_eq(b.cell_at(0, 0), PT.Cell.OPEN, "untouched cells stay OPEN")


func test_in_bounds() -> void:
	var b = Board.new(2, 2)
	assert_true(b.in_bounds(0, 0))
	assert_true(b.in_bounds(1, 1))
	assert_false(b.in_bounds(2, 0), "x past width is out")
	assert_false(b.in_bounds(0, 2), "y past height is out")
	assert_false(b.in_bounds(-1, 0), "negative is out")


func test_inlet_outlet_with_fixed_edge_dirs() -> void:
	var b = Board.new(4, 4)
	b.set_inlet(Vector2i(0, 1), PT.E)
	b.set_outlet(Vector2i(3, 2), PT.W)
	assert_eq(b.inlet_pos, Vector2i(0, 1))
	assert_eq(b.inlet_dir, PT.E)
	assert_eq(b.outlet_pos, Vector2i(3, 2))
	assert_eq(b.outlet_dir, PT.W)
