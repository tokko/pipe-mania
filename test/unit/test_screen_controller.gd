extends "res://addons/gut/test.gd"

const ScreenController = preload("res://scripts/screen_controller.gd")
const Run = preload("res://scripts/model/run.gd")


class MainDouble extends Node:
	var started_modes := []

	func start_game(mode: int) -> void:
		started_modes.append(mode)


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
	var main := MainDouble.new()
	var controller := ScreenController.new()
	add_child_autoqfree(main)
	add_child_autoqfree(controller)
	controller.setup(main)

	controller._on_menu_play()
	await get_tree().process_frame

	assert_eq(controller.screen_label(), "DIFFICULTY")
	assert_eq(main.started_modes, [])


func test_menu_difficulty_selection_starts_selected_mode() -> void:
	var main := MainDouble.new()
	var controller := ScreenController.new()
	add_child_autoqfree(main)
	add_child_autoqfree(controller)
	controller.setup(main)

	controller._on_menu_play()
	await get_tree().process_frame
	controller._screen_view.emit_signal("difficulty_selected", Run.Mode.HARD)

	assert_eq(main.started_modes, [Run.Mode.HARD])


func test_runover_new_game_waits_for_difficulty_before_starting_selected_mode() -> void:
	var main := MainDouble.new()
	var controller := ScreenController.new()
	add_child_autoqfree(main)
	add_child_autoqfree(controller)
	controller.setup(main)

	controller._on_runover_new_game()
	await get_tree().process_frame

	assert_eq(controller.screen_label(), "DIFFICULTY")
	assert_eq(main.started_modes, [])
	controller._screen_view.emit_signal("difficulty_selected", Run.Mode.MEDIUM)

	assert_eq(main.started_modes, [Run.Mode.MEDIUM])
