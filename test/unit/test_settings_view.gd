extends "res://addons/gut/test.gd"

const SettingsView = preload("res://scripts/view/settings_view.gd")

var _services: Node
var _saved_mode: String


func before_each() -> void:
	_services = get_node("/root/Services")
	_saved_mode = _services.ad_mode


func after_each() -> void:
	_services.ad_mode = _saved_mode


func _button_texts(view: SettingsView) -> Array[String]:
	var texts: Array[String] = []
	for node in view.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null:
			texts.append(button.text)
	return texts


func _mount(mode: String) -> SettingsView:
	_services.ad_mode = mode
	var view := SettingsView.new()
	view.setup(true)
	add_child(view)
	return view


func test_settings_has_only_audio_and_back_in_every_ad_mode() -> void:
	var stub := _mount("STUB")
	await get_tree().process_frame
	assert_eq(_button_texts(stub), ["Audio: ON", "Back"], "STUB settings has no purchase offer")
	assert_false(stub.has_signal("remove_ads_pressed"), "STUB settings has no purchase signal")
	stub.free()

	var test_mode := _mount("TEST")
	await get_tree().process_frame
	assert_eq(_button_texts(test_mode), ["Audio: ON", "Back"], "TEST settings has no purchase offer")
	assert_false(test_mode.has_signal("remove_ads_pressed"), "TEST settings has no purchase signal")
	test_mode.free()

	var live := _mount("LIVE")
	await get_tree().process_frame
	assert_eq(_button_texts(live), ["Audio: ON", "Back"], "LIVE settings has no purchase offer")
	assert_false(live.has_signal("remove_ads_pressed"), "LIVE settings has no purchase signal")
	live.free()
