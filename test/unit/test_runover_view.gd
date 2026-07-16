extends "res://addons/gut/test.gd"

const RunoverView = preload("res://scripts/view/runover_view.gd")


func test_submit_emits_one_initials_entry_for_displayed_score() -> void:
	var view = RunoverView.new()
	view.setup(12, 20, true, false, 3)
	var submitted := []
	view.initials_submitted.connect(func(initials: String) -> void: submitted.append(initials))
	add_child(view)
	await get_tree().process_frame
	var score: Label = view.find_child("RunScore", true, false) as Label
	assert_true(score.text.contains("12"), "qualifying screen displays the submitted run score")
	view._submit()
	view._submit()
	assert_eq(submitted, ["AAA"], "Submit records a qualifying run only once")
	view.free()
