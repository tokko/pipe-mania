extends CanvasLayer
## Branded splash: logo + game name on the dark backdrop, auto-advances after a beat or on tap.
## A single `_dismissed` guard makes timer+tap idempotent (and a freed-node timeout a no-op).

signal dismissed

const UiStyle = preload("res://scripts/view/ui_style.gd")

var _dismissed := false


func _init() -> void:
	layer = 5


func _ready() -> void:
	add_child(UiStyle.backdrop())
	var vb := UiStyle.centered_column(self)
	var icon := TextureRect.new()
	icon.texture = load("res://icon.svg")
	icon.custom_minimum_size = Vector2(160, 160)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(icon)
	vb.add_child(UiStyle.title(Config.GAME_NAME.to_upper()))
	get_tree().create_timer(1.5).timeout.connect(_advance)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()


func _advance() -> void:
	if _dismissed:  # timer + tap can both fire; only the first one advances
		return
	_dismissed = true
	dismissed.emit()


func connect_view(c) -> void:
	dismissed.connect(c._on_splash_dismissed)
