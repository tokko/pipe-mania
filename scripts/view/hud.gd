extends CanvasLayer
## Build-phase HUD: countdown, next-5 preview, live route-length readout. Observes the
## model via BoardView.state_changed (re-reads on change; never polls the model per frame).

signal go_pressed
signal menu_pressed  # abandon the run -> back to the start menu (only meaningful under the UI flow)

const Tile = preload("res://scripts/view/tile.gd")
const PT = preload("res://scripts/model/pipe_types.gd")
const UiStyle = preload("res://scripts/view/ui_style.gd")
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
var _status_content: Control
var _current_tile: Tile  # visible preview of the piece you're about to place
var _go_btn: Button       # hidden when flow starts (GO only makes sense during BUILD)


func _ready() -> void:
	var st := UiStyle.safe_top()  # push the top UI below a display cutout (0 without one / headless)
	var sb := UiStyle.safe_bottom()  # keep the bottom action bar above gesture navigation
	# Flow countdown is the hero of the build phase — large and top-left so it never gets lost.
	var status_panel := UiStyle.card()
	status_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_panel.offset_left = 12
	status_panel.offset_right = -12
	status_panel.offset_top = 8 + st
	status_panel.offset_bottom = 156 + st
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_panel)
	_status_content = Control.new()
	_status_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(_status_content)
	_countdown_label = _mk_label(Vector2(12, 4), 44)
	_score_label = _mk_label(Vector2(12, 56), 26)
	_route_label = _mk_label(Vector2(12, 84), 24)
	_preview_label = _mk_label(Vector2(12, 112), 22)
	_outcome_label = _mk_label(Vector2(260, 76), 22)
	var place_label := _mk_label(Vector2(432, 8), 20)
	place_label.text = "PLACE"
	place_label.size = Vector2(88, 24)
	place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current_tile = Tile.new()
	_current_tile.size = 72
	_current_tile.position = Vector2(440, 34)
	_status_content.add_child(_current_tile)
	# Onboarding banner: anchored just above the bottom bar, word-wrapped so it never runs off-screen.
	_tutorial_label = Label.new()
	_tutorial_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_tutorial_label.offset_left = 16
	_tutorial_label.offset_right = -16
	_tutorial_label.offset_top = -210
	_tutorial_label.offset_bottom = -110
	_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_tutorial_label)
	# Build-phase actions in a bottom bar anchored to the viewport bottom (tracks tall screens, no
	# magic y). Post-run actions (Revive/Leaderboard/...) live on the run-over screen, not here.
	var bar := Control.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -92 - sb
	bar.offset_bottom = -16 - sb
	add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.position = Vector2(16, 0)
	bar.add_child(hb)
	_go_btn = UiStyle.button("START FLOW", true)
	_go_btn.pressed.connect(func() -> void: go_pressed.emit())
	hb.add_child(_go_btn)
	var menu_btn := UiStyle.button("MENU")
	menu_btn.pressed.connect(func() -> void: menu_pressed.emit())
	hb.add_child(menu_btn)


## Show/hide GO — it only applies during BUILD; flow start hides it.
func show_go(shown: bool) -> void:
	if _go_btn != null:
		_go_btn.visible = shown


func _mk_label(pos: Vector2, size: int) -> Label:
	var l := UiStyle.label("", size)
	l.position = pos
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_content.add_child(l)
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
