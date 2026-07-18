extends "res://addons/gut/test.gd"

const ScreenController = preload("res://scripts/screen_controller.gd")
const Run = preload("res://scripts/model/run.gd")


class FakeMain extends Node:
	var revive_requests := 0
	var start_requests := 0
	var started_modes := []
	var teardown_requests := 0

	func request_revive() -> void:
		revive_requests += 1

	func start_game(mode: int = Run.Mode.EASY) -> void:
		start_requests += 1
		started_modes.append(mode)

	func teardown_game() -> void:
		teardown_requests += 1


class FakeRun extends RefCounted:
	var run_score := 0
	var high_score := 0
	var revived := false


func _runover_context() -> Dictionary:
	var host := Node.new()
	var main := FakeMain.new()
	var controller := ScreenController.new()
	var run := FakeRun.new()
	host.add_child(main)
	host.add_child(controller)
	add_child_autoqfree(host)
	controller.setup(main)
	controller.show_runover(run, 0)
	await get_tree().process_frame
	return {"host": host, "main": main, "controller": controller}


func test_handle_go_back_closes_an_open_leaderboard_modal() -> void:
	var host := Node.new()
	var controller := ScreenController.new()
	add_child(host)
	add_child(controller)
	controller.setup(host)
	controller._on_open_leaderboard()
	await get_tree().process_frame
	assert_eq(controller.screen_label(), "MODAL", "leaderboard is open before Back")
	assert_true(controller.handle_go_back(), "Back reports handled while a modal is open")
	assert_eq(controller.screen_label(), "GAME", "Back closes the open modal")
	host.free()
	controller.free()


func test_menu_play_mounts_difficulty_without_starting_game() -> void:
	var main := FakeMain.new()
	var controller := ScreenController.new()
	add_child_autoqfree(main)
	add_child_autoqfree(controller)
	controller.setup(main)

	controller._on_menu_play()
	await get_tree().process_frame

	assert_eq(controller.screen_label(), "DIFFICULTY")
	assert_eq(main.started_modes, [])


func test_menu_difficulty_selection_starts_selected_mode() -> void:
	var main := FakeMain.new()
	var controller := ScreenController.new()
	add_child_autoqfree(main)
	add_child_autoqfree(controller)
	controller.setup(main)

	controller._on_menu_play()
	await get_tree().process_frame
	controller._screen_view.emit_signal("difficulty_selected", Run.Mode.HARD)

	assert_eq(main.started_modes, [Run.Mode.HARD])


func test_pending_difficulty_is_retained_disabled_and_ignores_reentry() -> void:
	var main := FakeMain.new()
	var controller := ScreenController.new()
	add_child_autoqfree(main)
	add_child_autoqfree(controller)
	controller.setup(main)
	controller._on_menu_play()
	await get_tree().process_frame
	var difficulty := controller._screen_view

	difficulty.emit_signal("difficulty_selected", Run.Mode.HARD)
	assert_eq(controller.screen_label(), "DIFFICULTY", "selector remains mounted while start is pending")
	assert_eq(main.started_modes, [Run.Mode.HARD], "the selected mode is requested once")
	for button in difficulty.find_children("*", "Button", true, false):
		assert_true((button as Button).disabled, "pending selector disables every mode")

	difficulty.emit_signal("difficulty_selected", Run.Mode.EASY)
	controller._on_menu_play()
	assert_eq(main.started_modes, [Run.Mode.HARD], "duplicate selection and Play re-entry are ignored")
	assert_true(controller._screen_view == difficulty, "re-entry does not replace the holding surface")

	controller.complete_new_game()
	assert_eq(controller.screen_label(), "GAME", "the terminal removes the selector")


func test_runover_new_game_waits_for_difficulty_before_starting_selected_mode() -> void:
	var context := await _runover_context()
	var controller: ScreenController = context["controller"]
	var main: FakeMain = context["main"]

	controller._on_runover_new_game()
	await get_tree().process_frame

	assert_eq(controller.screen_label(), "DIFFICULTY")
	assert_eq(main.started_modes, [])
	controller._screen_view.emit_signal("difficulty_selected", Run.Mode.MEDIUM)

	assert_eq(main.started_modes, [Run.Mode.MEDIUM])


func test_revive_request_stays_runover_until_explicit_completion() -> void:
	var context := await _runover_context()
	var controller: ScreenController = context["controller"]
	var main: FakeMain = context["main"]

	controller._on_runover_revive()
	assert_eq(controller.screen_label(), "RUNOVER", "revive request keeps Run Over visible")
	assert_eq(main.revive_requests, 1, "revive is requested once")
	controller._on_runover_revive()
	assert_eq(main.revive_requests, 1, "duplicate revive request is ignored")

	assert_true(controller.has_method("complete_revive"), "controller exposes explicit revive completion")
	if controller.has_method("complete_revive"):
		controller.call("complete_revive", false)
		assert_eq(controller.screen_label(), "RUNOVER", "revive failure restores Run Over")
		controller._on_runover_revive()
		controller.call("complete_revive", true)
		assert_eq(controller.screen_label(), "GAME", "only successful explicit completion removes overlay")


func test_rewarded_pending_rejects_new_game_and_menu() -> void:
	var context := await _runover_context()
	var controller: ScreenController = context["controller"]
	var main: FakeMain = context["main"]

	controller._on_runover_revive()
	controller._on_runover_new_game()
	assert_eq(controller.screen_label(), "RUNOVER", "rewarded pending rejects New Game")
	controller._on_runover_menu()

	assert_eq(main.revive_requests, 1, "one rewarded request remains active")
	assert_eq(main.start_requests, 0, "rewarded pending does not start a mode")
	assert_eq(main.teardown_requests, 0, "rewarded pending rejects Menu")
	assert_eq(controller.screen_label(), "RUNOVER", "Run Over remains the rewarded holding surface")
