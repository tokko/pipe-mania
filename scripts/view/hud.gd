extends CanvasLayer
## Build-phase HUD: countdown, next-5 preview, live route-length readout. Observes the
## model via BoardView.state_changed (re-reads on change; never polls the model per frame).

signal rotate_pressed

const _PIECE_NAME := {0: "-", 1: "I", 2: "L", 3: "+"}  # NONE/STRAIGHT/BEND/CROSS glyphs

var _gs
var _route: int = 0
var _preview: Array = []

var _countdown_label: Label
var _route_label: Label
var _preview_label: Label
var _settings_btn: Button


func _ready() -> void:
	_countdown_label = _mk_label(Vector2(16, 16))
	_route_label = _mk_label(Vector2(16, 48))
	_preview_label = _mk_label(Vector2(16, 80))
	_settings_btn = Button.new()
	_settings_btn.text = "Rot: OFF"
	_settings_btn.position = Vector2(560, 16)
	_settings_btn.pressed.connect(_on_settings)
	add_child(_settings_btn)
	var rot_btn := Button.new()
	rot_btn.text = "Rotate"
	rot_btn.position = Vector2(560, 56)
	rot_btn.pressed.connect(func() -> void: rotate_pressed.emit())
	add_child(rot_btn)


func _on_settings() -> void:
	Settings.toggle_rotation()
	_settings_btn.text = "Rot: " + ("ON" if Settings.rotation_enabled else "OFF")


func _mk_label(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	add_child(l)
	return l


## Bind to a BoardView: read its model, refresh now, and refresh on every state change.
func bind(board_view) -> void:
	_gs = board_view.gs
	board_view.state_changed.connect(_on_state_changed)
	refresh_from(_gs)


func _on_state_changed() -> void:
	refresh_from(_gs)


func refresh_from(gs) -> void:
	_route = gs.dry_route_length()
	_preview = gs.preview(5)
	_route_label.text = "Route: %d" % _route
	var glyphs := ""
	for p in _preview:
		glyphs += String(_PIECE_NAME.get(p, "?"))
	_preview_label.text = "Next: " + glyphs


func set_countdown(secs: int) -> void:
	_countdown_label.text = "Time: %d" % secs


# --- accessors for the headless [integration] gate ---
func route_value() -> int:
	return _route


func preview_len() -> int:
	return _preview.size()


func countdown_text() -> String:
	return _countdown_label.text
