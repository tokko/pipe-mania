extends CanvasLayer
## Build-phase HUD: countdown, next-5 preview, live route-length readout. Observes the
## model via BoardView.state_changed (re-reads on change; never polls the model per frame).

signal rotate_pressed
signal go_pressed
signal restart_pressed

const _PIECE_NAME := {0: "-", 1: "I", 2: "L", 3: "+"}  # NONE/STRAIGHT/BEND/CROSS glyphs

var _gs
var _route: int = 0
var _preview: Array = []

var _countdown_label: Label
var _route_label: Label
var _preview_label: Label
var _outcome_label: Label
var _score_label: Label
var _tutorial_label: Label
var _settings_btn: Button


func _ready() -> void:
	_countdown_label = _mk_label(Vector2(16, 16))
	_route_label = _mk_label(Vector2(16, 48))
	_preview_label = _mk_label(Vector2(16, 80))
	_outcome_label = _mk_label(Vector2(16, 112))
	_score_label = _mk_label(Vector2(220, 16))
	_tutorial_label = _mk_label(Vector2(16, 1180))  # first-run onboarding banner (bottom)
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
	var go_btn := Button.new()
	go_btn.text = "GO"
	go_btn.position = Vector2(560, 96)
	go_btn.pressed.connect(func() -> void: go_pressed.emit())
	add_child(go_btn)
	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.position = Vector2(560, 136)
	restart_btn.pressed.connect(func() -> void: restart_pressed.emit())
	add_child(restart_btn)


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
	if not board_view.state_changed.is_connected(_on_state_changed):
		board_view.state_changed.connect(_on_state_changed)  # idempotent across re-binds (E4 reload)
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


func set_outcome(text: String) -> void:
	_outcome_label.text = text


func outcome_text() -> String:
	return _outcome_label.text


func set_scores(run_score: int, high_score: int) -> void:
	_score_label.text = "Score: %d  Best: %d" % [run_score, high_score]


func score_text() -> String:
	return _score_label.text


func set_tutorial(text: String) -> void:
	_tutorial_label.text = text


func clear_tutorial() -> void:
	_tutorial_label.text = ""


func tutorial_text() -> String:
	return _tutorial_label.text


# --- accessors for the headless [integration] gate ---
func route_value() -> int:
	return _route


func preview_len() -> int:
	return _preview.size()


func countdown_text() -> String:
	return _countdown_label.text
