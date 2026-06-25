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
	var vb := UiStyle.centered_column(self)
	vb.add_child(UiStyle.title("LEADERBOARD", 48))
	if _entries.is_empty():
		vb.add_child(UiStyle.label("No scores yet"))
	else:
		var rank := 1
		for e in _entries:
			vb.add_child(UiStyle.label("%d.   %s   %d" % [rank, e.get("name", "?"), int(e.get("score", 0))]))
			rank += 1
	var back := UiStyle.button("Back")
	back.pressed.connect(func() -> void: closed.emit())
	vb.add_child(back)


func connect_view(c) -> void:
	closed.connect(c._on_close_modal)
