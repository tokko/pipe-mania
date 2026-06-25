extends CanvasLayer
## Build-phase HUD: countdown, next-5 preview, live route-length readout. Observes the
## model via BoardView.state_changed (re-reads on change; never polls the model per frame).

signal go_pressed
signal restart_pressed
signal revive_pressed
signal remove_ads_pressed
signal leaderboard_pressed

const Tile = preload("res://scripts/view/tile.gd")
const PT = preload("res://scripts/model/pipe_types.gd")
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
var _current_tile: Tile  # visible preview of the piece you're about to place


func _ready() -> void:
	# Flow countdown is the hero of the build phase — large and top-left so it never gets lost.
	_countdown_label = _mk_label(Vector2(16, 8))
	_countdown_label.add_theme_font_size_override("font_size", 40)
	_score_label = _mk_label(Vector2(16, 60))
	_route_label = _mk_label(Vector2(16, 90))
	_preview_label = _mk_label(Vector2(16, 118))
	_outcome_label = _mk_label(Vector2(260, 60))
	# Onboarding banner: bottom area, word-wrapped so it never runs off-screen.
	_tutorial_label = _mk_label(Vector2(16, 1078))
	_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tutorial_label.size = Vector2(690, 0)
	_tutorial_label.custom_minimum_size = Vector2(690, 0)
	_mk_label(Vector2(470, 12)).text = "Place:"  # label above the current-piece preview
	_current_tile = Tile.new()
	_current_tile.size = 96
	_current_tile.position = Vector2(470, 40)
	add_child(_current_tile)
	# Action buttons in a BOTTOM bar (below the board) so they never cover the grid or its ports.
	var by := 1212
	_mk_btn("GO", Vector2(12, by), func() -> void: go_pressed.emit())
	_mk_btn("Restart", Vector2(96, by), func() -> void: restart_pressed.emit())
	_mk_btn("Revive", Vector2(216, by), func() -> void: revive_pressed.emit())
	_mk_btn("Remove Ads", Vector2(316, by), func() -> void: remove_ads_pressed.emit())
	_mk_btn("Leaderboard", Vector2(470, by), func() -> void: leaderboard_pressed.emit())


func _mk_btn(text: String, pos: Vector2, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.pressed.connect(cb)
	add_child(b)


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
	_current_tile.refresh(PT.Cell.OPEN, gs.current_piece(), gs.current_rot(), false, false)  # what you place next


func set_countdown(secs: int) -> void:
	_countdown_label.text = "Flow in %ds" % secs


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


func current_piece_shown() -> int:
	return _current_tile.piece
