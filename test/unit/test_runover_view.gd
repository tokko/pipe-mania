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


func test_runover_exposes_named_ad_controls() -> void:
	var view := RunoverView.new()
	view.setup(12, 20, true, true, 3)
	add_child(view)
	await get_tree().process_frame

	assert_not_null(view.find_child("ReviveButton", true, false), "revive action has a stable name")
	assert_not_null(view.find_child("NewGameButton", true, false), "new-game action has a stable name")
	assert_not_null(view.find_child("MenuButton", true, false), "menu action has a stable name")
	assert_not_null(view.find_child("AdStatus", true, false), "ad status has a stable name")
	view.free()


func test_shared_ad_pending_disables_conflicting_actions_and_failure_restores_them() -> void:
	var view := RunoverView.new()
	view.setup(12, 20, true, true, 3)
	add_child(view)
	await get_tree().process_frame

	var revive := view.find_child("ReviveButton", true, false) as Button
	var new_game := view.find_child("NewGameButton", true, false) as Button
	var menu := view.find_child("MenuButton", true, false) as Button
	assert_true(view.has_method("set_ad_pending"), "view exposes one shared pending-state seam")
	if revive == null or new_game == null or menu == null or not view.has_method("set_ad_pending"):
		view.free()
		return

	view.call("set_ad_pending", true)
	assert_true(revive.disabled, "pending ad disables Revive")
	assert_true(new_game.disabled, "pending ad disables New Game")
	assert_true(menu.disabled, "pending ad disables Menu")
	assert_true(view.has_method("show_ad_failure"), "view exposes the reward-failure seam")
	if view.has_method("show_ad_failure"):
		view.call("show_ad_failure")
		assert_eq((view.find_child("AdStatus", true, false) as Label).text,
			"Ad unavailable. Try again.", "reward failure uses the exact status text")
		assert_false(revive.disabled, "reward failure restores Revive")
		assert_false(new_game.disabled, "reward failure restores New Game")
		assert_false(menu.disabled, "reward failure restores Menu")
	view.free()
