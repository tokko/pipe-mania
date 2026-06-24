extends "res://addons/gut/test.gd"
## S4.2 — SaveStore: the single high-score persistence boundary (JSON in user://).

const SaveStore = preload("res://scripts/save_store.gd")


func _clear() -> void:
	var d := DirAccess.open("user://")
	if d and d.file_exists("highscore.json"):
		d.remove("highscore.json")


func test_absent_returns_zero() -> void:
	_clear()
	assert_eq(SaveStore.load_high(), 0, "no save file -> high score 0")


func test_save_then_load_roundtrip() -> void:  # acceptance: high score survives a reload
	_clear()
	SaveStore.save_high(42)
	assert_eq(SaveStore.load_high(), 42, "high score survives a SaveStore reload")


func test_overwrite_keeps_latest() -> void:
	_clear()
	SaveStore.save_high(10)
	SaveStore.save_high(25)
	assert_eq(SaveStore.load_high(), 25, "latest save wins")


func test_wrong_shape_returns_zero() -> void:  # control (must be able to go red)
	# Valid JSON but not the expected {"high": int} dict -> 0. (Avoids triggering Godot's
	# JSON-parse error log on raw garbage, which would spam the gate's stderr.)
	var f := FileAccess.open("user://highscore.json", FileAccess.WRITE)
	f.store_string("[1, 2, 3]")
	f.close()
	assert_eq(SaveStore.load_high(), 0, "JSON of the wrong shape -> 0, no crash")
