extends "res://addons/gut/test.gd"
## E0/S0.2 smoke test — proves the gate runs and the project parses.


func test_config_singleton_exposes_game_name() -> void:
	assert_ne(Config.GAME_NAME, "", "Config.GAME_NAME must be set")


func test_arithmetic_sanity() -> void:
	assert_eq(2 + 2, 4, "the gate can evaluate a real assertion")
