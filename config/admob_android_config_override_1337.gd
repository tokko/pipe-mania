extends "res://addons/admob/android/config.gd"

const MonetizationConfig := preload("res://scripts/monetization_config.gd")

var _application_id: String


func _init() -> void:
	var selection: Dictionary = MonetizationConfig.resolve_export_ads_selection(
		OS.get_environment(MonetizationConfig.EXPORT_SELECTOR_ENV)
	)
	_application_id = selection.manifest_app_id
	for library in libraries:
		if library.path == "ads":
			library.is_enabled = selection.ads_enabled


func _get(property: StringName) -> Variant:
	if property == &"APPLICATION_ID":
		return _application_id
	return null
