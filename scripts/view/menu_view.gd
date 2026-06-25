extends CanvasLayer
## Start menu: title, best score, and Play / Leaderboard / Settings. The controller wires the
## signals (connect_view) and feeds the best score (setup) — the view never reads SaveStore.

signal play_pressed
signal leaderboard_pressed
signal settings_pressed

const UiStyle = preload("res://scripts/view/ui_style.gd")

var _best := 0


func _init() -> void:
	layer = 5


func setup(best: int) -> void:
	_best = best


func _ready() -> void:
	add_child(UiStyle.backdrop())
	var vb := UiStyle.centered_column(self)
	vb.add_child(UiStyle.title(Config.GAME_NAME.to_upper()))
	vb.add_child(UiStyle.label("Best: %d" % _best))
	var play := UiStyle.button("Play")
	play.pressed.connect(func() -> void: play_pressed.emit())
	vb.add_child(play)
	var lb := UiStyle.button("Leaderboard")
	lb.pressed.connect(func() -> void: leaderboard_pressed.emit())
	vb.add_child(lb)
	var st := UiStyle.button("Settings")
	st.pressed.connect(func() -> void: settings_pressed.emit())
	vb.add_child(st)


func connect_view(c) -> void:
	play_pressed.connect(c._on_menu_play)
	leaderboard_pressed.connect(c._on_open_leaderboard)
	settings_pressed.connect(c._on_open_settings)
