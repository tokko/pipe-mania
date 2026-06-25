extends CanvasLayer
## Run-over screen (modal overlay on the frozen board): score + best, a 3-initial entry when the
## score makes the local top-10, and the contextual actions. The controller decides `qualifies`
## and `can_revive` and passes them in (setup); the view only renders + emits.

signal revive_pressed
signal new_game_pressed
signal leaderboard_pressed
signal menu_pressed
signal initials_submitted(initials)

const UiStyle = preload("res://scripts/view/ui_style.gd")

var _run_score := 0
var _best := 0
var _qualifies := false
var _can_revive := false
var _initials: LineEdit


func _init() -> void:
	layer = 10


func setup(run_score: int, best: int, qualifies: bool, can_revive: bool) -> void:
	_run_score = run_score
	_best = best
	_qualifies = qualifies
	_can_revive = can_revive


func _ready() -> void:
	add_child(UiStyle.backdrop())
	var vb := UiStyle.centered_column(self)
	vb.add_child(UiStyle.title("RUN OVER", 56))
	vb.add_child(UiStyle.label("Score: %d     Best: %d" % [_run_score, _best]))
	if _qualifies:
		vb.add_child(UiStyle.label("New high score! Enter your initials:"))
		_initials = LineEdit.new()
		_initials.max_length = 3
		_initials.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_initials.custom_minimum_size = Vector2(180, 56)
		_initials.text_changed.connect(_on_initials_typed)
		vb.add_child(_initials)
		var submit := UiStyle.button("Submit")
		submit.pressed.connect(_submit)
		vb.add_child(submit)
	if _can_revive:
		var rv := UiStyle.button("Revive (watch ad)")
		rv.pressed.connect(func() -> void: revive_pressed.emit())
		vb.add_child(rv)
	var ng := UiStyle.button("New Game")
	ng.pressed.connect(func() -> void: new_game_pressed.emit())
	vb.add_child(ng)
	var lb := UiStyle.button("Leaderboard")
	lb.pressed.connect(func() -> void: leaderboard_pressed.emit())
	vb.add_child(lb)
	var mn := UiStyle.button("Menu")
	mn.pressed.connect(func() -> void: menu_pressed.emit())
	vb.add_child(mn)


func _on_initials_typed(t: String) -> void:
	var up := t.to_upper()
	if up != t:
		_initials.text = up
		_initials.caret_column = up.length()


func _submit() -> void:
	var initials := _initials.text.strip_edges() if _initials != null else ""
	if initials == "":
		initials = "AAA"
	_initials.editable = false  # one submit per run-over
	initials_submitted.emit(initials)


func connect_view(c) -> void:
	revive_pressed.connect(c._on_runover_revive)
	new_game_pressed.connect(c._on_runover_new_game)
	leaderboard_pressed.connect(c._on_open_leaderboard)
	menu_pressed.connect(c._on_runover_menu)
	initials_submitted.connect(c._on_initials_submitted)
