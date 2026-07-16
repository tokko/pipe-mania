extends "res://addons/gut/test.gd"

const LeaderboardView = preload("res://scripts/view/leaderboard_view.gd")


func test_populated_leaderboard_is_scrollable_and_ranked() -> void:
	var view = LeaderboardView.new()
	var entries := []
	for rank in range(10):
		entries.append({"name": "AAA", "score": 100 - rank, "date": "2026-07-%02d" % (16 - rank)})
	view.setup(entries)
	add_child(view)
	await get_tree().process_frame
	var scroll: ScrollContainer = view.find_child("LeaderboardScroll", true, false) as ScrollContainer
	assert_not_null(scroll, "ranked entries live in a ScrollContainer")
	assert_gt(scroll.get_v_scroll_bar().max_value, 0.0, "ten rows overflow the fixed viewport")
	var grid: GridContainer = view.find_child("LeaderboardGrid", true, false) as GridContainer
	assert_eq(grid.mouse_filter, Control.MOUSE_FILTER_IGNORE, "row labels do not consume scroll drags")
	for child in grid.get_children():
		if child is Label:
			assert_eq((child as Label).mouse_filter, Control.MOUSE_FILTER_IGNORE, "mounted leaderboard labels do not consume scroll drags")
	var first: Label = view.find_child("Rank1", true, false) as Label
	var second: Label = view.find_child("Rank2", true, false) as Label
	assert_eq(first.text, "1.")
	assert_eq(second.text, "2.")
	var date: Label = view.find_child("Date1", true, false) as Label
	assert_eq(date.text, "2026-07-16", "first row displays its date")
	view.free()


func test_legacy_entry_displays_date_placeholder() -> void:
	var view = LeaderboardView.new()
	view.setup([{"name": "OLD", "score": 8}])
	add_child(view)
	await get_tree().process_frame
	var date: Label = view.find_child("Date1", true, false) as Label
	assert_eq(date.text, "-", "legacy date-less entry remains readable")
	view.free()


func test_ui_cancel_closes_leaderboard() -> void:
	var view = LeaderboardView.new()
	var closed := [false]
	view.closed.connect(func() -> void: closed[0] = true)
	add_child(view)
	await get_tree().process_frame
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	view._unhandled_input(event)
	assert_true(closed[0], "ui_cancel closes the modal")
	assert_true(get_viewport().is_input_handled(), "ui_cancel cannot reach the revealed screen")
	view.free()
