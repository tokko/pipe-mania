extends Node
## Global game settings (autoload). In-memory for now; E4's SaveStore will persist them.
## rotation_enabled is the opt-in "easier mode" toggle chosen in-run (default off = classic
## fixed-orientation placement).

var rotation_enabled := false
var audio_enabled := true
var haptics_enabled := true


func toggle_rotation() -> void:
	rotation_enabled = not rotation_enabled


func toggle_audio() -> void:
	audio_enabled = not audio_enabled


func toggle_haptics() -> void:
	haptics_enabled = not haptics_enabled
