extends Node
## Global game settings (autoload). `audio_enabled` + `ads_removed` mirror SaveStore: loaded once
## at boot (_ready), and every write goes through SaveStore so the value persists. Settings is the
## sole read path; SaveStore is the sole write path; _ready is the single reconcile point.
## No rotation toggle — the deck hands out pre-oriented pieces (classic Pipe Mania).

const SaveStore = preload("res://scripts/save_store.gd")

var audio_enabled := true
var ads_removed := false


func _ready() -> void:
	audio_enabled = SaveStore.load_audio_enabled()
	ads_removed = SaveStore.load_ads_removed()


func toggle_audio() -> void:
	audio_enabled = not audio_enabled
	SaveStore.save_audio_enabled(audio_enabled)


func set_ads_removed(value: bool) -> void:
	ads_removed = value
	SaveStore.save_ads_removed(value)
