extends "res://addons/gut/test.gd"

const DifficultyView = preload("res://scripts/view/difficulty_view.gd")
const Run = preload("res://scripts/model/run.gd")


func _button(view: DifficultyView, button_name: String) -> Button:
	return view.find_child(button_name, true, false) as Button


func test_all_difficulty_choices_are_labeled_and_emit_their_mode() -> void:
	var view := DifficultyView.new()
	var selected := []
	view.difficulty_selected.connect(func(mode: int) -> void: selected.append(mode))
	add_child(view)
	await get_tree().process_frame

	var easy := _button(view, "EasyButton")
	var medium := _button(view, "MediumButton")
	var hard := _button(view, "HardButton")

	assert_eq(easy.text, "Easy\n90 seconds | 1x score")
	assert_eq(medium.text, "Medium\n60 seconds | 1.5x score")
	assert_eq(hard.text, "Hard\n30 seconds | 2x score")

	easy.emit_signal("pressed")
	medium.emit_signal("pressed")
	hard.emit_signal("pressed")

	assert_eq(selected, [Run.Mode.EASY, Run.Mode.MEDIUM, Run.Mode.HARD])
	view.free()
