extends "res://addons/gut/test.gd"


func test_android_export_plugin_compiles() -> void:
	var exporter_script: Script = load("res://addons/admob/internal/exporters/android/export_plugin.gd")
	assert_true(
		exporter_script != null and exporter_script.can_instantiate(),
		"AdMob Android export plugin must compile"
	)


func test_project_override_compiles_and_is_vendor_config_compatible() -> void:
	assert_file_exists("res://config/admob_android_config_override_1337.gd")
	if not FileAccess.file_exists("res://config/admob_android_config_override_1337.gd"):
		return
	var override_script: Script = load("res://config/admob_android_config_override_1337.gd")
	var vendor_config: Script = load("res://addons/admob/android/config.gd")
	assert_true(override_script != null and override_script.can_instantiate())
	var config = override_script.new()
	assert_true(is_instance_of(config, vendor_config))


func test_default_project_override_disables_ads() -> void:
	assert_file_exists("res://config/admob_android_config_override_1337.gd")
	if not FileAccess.file_exists("res://config/admob_android_config_override_1337.gd"):
		return
	var previous := OS.get_environment("AQUEDUCT_ADS_EXPORT_TARGET")
	OS.set_environment("AQUEDUCT_ADS_EXPORT_TARGET", "")
	var config = _create_override_config()
	_restore_selector(previous)
	assert_eq(config.APPLICATION_ID, "")
	assert_false(_ads_library_enabled(config))


func test_test_project_override_enables_ads_with_exact_demo_app_id() -> void:
	assert_file_exists("res://config/admob_android_config_override_1337.gd")
	if not FileAccess.file_exists("res://config/admob_android_config_override_1337.gd"):
		return
	var previous := OS.get_environment("AQUEDUCT_ADS_EXPORT_TARGET")
	OS.set_environment("AQUEDUCT_ADS_EXPORT_TARGET", "Test")
	var config = _create_override_config()
	_restore_selector(previous)
	assert_eq(config.APPLICATION_ID, "ca-app-pub-3940256099942544~3347511713")
	assert_true(_ads_library_enabled(config))


func _create_override_config():
	return load("res://config/admob_android_config_override_1337.gd").new()


func _ads_library_enabled(config) -> bool:
	for library in config.libraries:
		if library.path == "ads":
			return library.is_enabled
	return false


func _restore_selector(previous: String) -> void:
	OS.set_environment("AQUEDUCT_ADS_EXPORT_TARGET", previous)
