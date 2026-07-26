extends CanvasLayer

signal difficulty_selected(mode: int)

const Run = preload("res://scripts/model/run.gd")
const UiStyle = preload("res://scripts/view/ui_style.gd")

var _buttons: Array[Button] = []


func _init() -> void:
	layer = 5


func _ready() -> void:
	add_child(UiStyle.backdrop())
	var column := UiStyle.centered_card(self)
	column.add_child(UiStyle.title("CHOOSE DIFFICULTY", 44))
	_add_mode_button(column, Run.Mode.EASY, true)
	_add_mode_button(column, Run.Mode.MEDIUM, false)
	_add_mode_button(column, Run.Mode.HARD, false)


func _add_mode_button(column: VBoxContainer, mode: int, primary: bool) -> void:
	var config: Dictionary = Run.mode_config(mode)
	var score_label := "1.5" if int(config.score_denominator) == 2 else str(int(config.score_numerator))
	var button := UiStyle.button(
		"%s\n%d seconds | %sx score" % [str(config.name), int(config.build_seconds), score_label],
		primary
	)
	button.name = "%sButton" % str(config.name)
	button.pressed.connect(difficulty_selected.emit.bind(mode))
	column.add_child(button)
	_buttons.append(button)


func set_ad_pending(pending: bool) -> void:
	for button in _buttons:
		button.disabled = pending


func connect_view(controller) -> void:
	difficulty_selected.connect(controller._on_difficulty_selected)
