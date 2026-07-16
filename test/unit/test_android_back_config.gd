extends "res://addons/gut/test.gd"


func test_android_back_is_not_consumed_by_the_activity() -> void:
	const setting := "application/config/quit_on_go_back"
	assert_false(ProjectSettings.get_setting(setting), "Android Back must reach the scene handler")
