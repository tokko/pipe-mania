extends CanvasLayer
## Leaderboard modal: lists the local top-10. The controller passes the entries (setup) — the view
## never reads SaveStore. A future online backend just hands a different array to the same setup.

signal closed

const UiStyle = preload("res://scripts/view/ui_style.gd")

var _entries: Array = []


func _init() -> void:
	layer = 15


func setup(entries: Array) -> void:
	_entries = entries


func _ready() -> void:
	add_child(UiStyle.backdrop())
	var vb := UiStyle.centered_card(self)
	vb.add_child(UiStyle.title("LEADERBOARD", 48))
	if _entries.is_empty():
		vb.add_child(UiStyle.label("No scores yet"))
	else:
		var scroll := ScrollContainer.new()
		scroll.name = "LeaderboardScroll"
		scroll.custom_minimum_size = Vector2(0, 260)
		var grid := GridContainer.new()
		grid.name = "LeaderboardGrid"
		grid.columns = 4
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.custom_minimum_size = Vector2(360, 0)
		_add_row(grid, ["Rank", "Name", "Score", "Date"])
		var rank := 1
		for e in _entries:
			_add_row(grid, ["%d." % rank, str(e.get("name", "?")), str(int(e.get("score", 0))), str(e.get("date", "-"))], rank)
			rank += 1
		scroll.add_child(grid)
		vb.add_child(scroll)
	var back := UiStyle.button("Back")
	back.pressed.connect(func() -> void: closed.emit())
	vb.add_child(back)


func connect_view(c) -> void:
	closed.connect(c._on_close_modal)


func _add_row(grid: GridContainer, values: Array[String], rank: int = 0) -> void:
	for column in values.size():
		var label := UiStyle.label(values[column], 22)
		label.custom_minimum_size = [Vector2(45, 0), Vector2(95, 0), Vector2(75, 0), Vector2(115, 0)][column]
		if rank > 0:
			if column == 0:
				label.name = "Rank%d" % rank
			elif column == 3:
				label.name = "Date%d" % rank
		grid.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
