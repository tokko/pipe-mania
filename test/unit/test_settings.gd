extends "res://addons/gut/test.gd"
## Settings: runtime mirror of the persisted audio_enabled flag. Writes go through
## SaveStore so they survive a relaunch; _ready reconciles from disk.

const Settings = preload("res://scripts/settings.gd")
const SaveStore = preload("res://scripts/save_store.gd")


func _clear() -> void:
	var d := DirAccess.open("user://")
	if d and d.file_exists("highscore.json"):
		d.remove("highscore.json")


func test_toggle_audio_persists() -> void:
	_clear()
	var s = autofree(Settings.new())
	s.audio_enabled = true
	s.toggle_audio()
	assert_false(s.audio_enabled, "runtime mirror flipped")
	assert_false(SaveStore.load_audio_enabled(), "audio toggle persisted to SaveStore")


func test_ready_reconciles_from_disk() -> void:
	_clear()
	SaveStore.save_audio_enabled(false)
	var s = autofree(Settings.new())
	s._ready()  # autoloads run _ready at boot; here we drive it explicitly
	assert_false(s.audio_enabled, "_ready loads audio_enabled from disk")
