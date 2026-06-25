extends CanvasLayer
## Settings modal: audio toggle + Remove Ads (hidden once purchased). The controller owns the
## persistence (Settings/SaveStore) — the view just reflects state (setup) and emits intents.

signal closed
signal audio_toggled
signal remove_ads_pressed

const UiStyle = preload("res://scripts/view/ui_style.gd")

var _audio_on := true
var _ads_removed := false
var _audio_btn: Button


func _init() -> void:
	layer = 15


func setup(audio_on: bool, ads_removed: bool) -> void:
	_audio_on = audio_on
	_ads_removed = ads_removed


func _ready() -> void:
	add_child(UiStyle.backdrop())
	var vb := UiStyle.centered_column(self)
	vb.add_child(UiStyle.title("SETTINGS", 48))
	_audio_btn = UiStyle.button(_audio_label())
	_audio_btn.pressed.connect(_on_audio)
	vb.add_child(_audio_btn)
	if _ads_removed:
		vb.add_child(UiStyle.label("Ads removed - thank you!"))
	else:
		var ra := UiStyle.button("Remove Ads")
		ra.pressed.connect(func() -> void: remove_ads_pressed.emit())
		vb.add_child(ra)
	var back := UiStyle.button("Back")
	back.pressed.connect(func() -> void: closed.emit())
	vb.add_child(back)


func _audio_label() -> String:
	return "Audio: ON" if _audio_on else "Audio: OFF"


func _on_audio() -> void:
	_audio_on = not _audio_on
	_audio_btn.text = _audio_label()
	audio_toggled.emit()


func connect_view(c) -> void:
	closed.connect(c._on_close_modal)
	audio_toggled.connect(c._on_settings_audio_toggled)
	remove_ads_pressed.connect(c._on_settings_remove_ads)
