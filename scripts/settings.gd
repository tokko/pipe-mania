extends Node
## Global game settings (autoload). In-memory for now; E4's SaveStore will persist them.
## No rotation toggle — the deck hands out pre-oriented pieces (classic Pipe Mania).

var audio_enabled := true


func toggle_audio() -> void:
	audio_enabled = not audio_enabled
