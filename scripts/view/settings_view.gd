extends CanvasLayer
## Settings modal: audio toggle. The controller owns the
## persistence (Settings/SaveStore) — the view just reflects state (setup) and emits intents.

signal closed
signal audio_toggled

const UiStyle = preload("res://scripts/view/ui_style.gd")

var _audio_on := true
var _audio_btn: Button


func _init() -> void:
	layer = 15


func setup(audio_on: bool) -> void:
	_audio_on = audio_on


func _ready() -> void:
	add_child(UiStyle.backdrop())
	var vb := UiStyle.centered_card(self)
	vb.add_child(UiStyle.title("SETTINGS", 48))
	_audio_btn = UiStyle.button(_audio_label())
	_audio_btn.pressed.connect(_on_audio)
	vb.add_child(_audio_btn)
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
