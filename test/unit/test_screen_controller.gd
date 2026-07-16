extends "res://addons/gut/test.gd"

const ScreenController = preload("res://scripts/screen_controller.gd")


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
