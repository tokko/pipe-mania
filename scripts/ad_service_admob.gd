extends RefCounted

signal reward_earned(kind: String)
signal reward_failed(kind: String)
signal interstitial_finished()

const MonetizationConfig = preload("res://scripts/monetization_config.gd")

enum BootState { NEW, CONSENT, INITIALIZING, READY, FAILED }

var _harness: WeakRef
var _rewarded_id: String
var _interstitial_id: String
var _is_test_build: bool
var _boot_state: BootState = BootState.NEW
var _request_id: int = 0
var _request_type: String = ""
var _reward_kind: String = ""
var _rewarded_ad
var _interstitial_ad
var _consent_information


func _init(harness = null, rewarded_id: String = "", interstitial_id: String = "", is_test_build: bool = false) -> void:
	if harness != null:
		_harness = weakref(harness)
	_rewarded_id = rewarded_id
	_interstitial_id = interstitial_id
	_is_test_build = is_test_build


func show_rewarded(kind: String) -> void:
	_begin_request("rewarded", kind)


func show_interstitial() -> void:
	_begin_request("interstitial")


func _begin_request(type: String, kind: String = "") -> void:
	if _request_type != "":
		return
	_request_id += 1
	_request_type = type
	_reward_kind = kind

	match _boot_state:
		BootState.NEW:
			_bootstrap()
		BootState.READY:
			_load_request()
		BootState.FAILED:
			_finish_failure(_request_id)


func _bootstrap() -> void:
	var harness: Variant = _get_harness()
	if harness != null:
		_boot_state = BootState.CONSENT
		harness.request_consent(_create_consent_request_parameters(), _on_consent_granted, _on_consent_failed, _on_consent_denied)
		return

	var has_ump := Engine.has_singleton(MonetizationConfig.ADMOB_UMP_SINGLETON)
	var has_consent := Engine.has_singleton(MonetizationConfig.ADMOB_CONSENT_SINGLETON)
	if has_ump != has_consent:
		_fail_boot()
	elif has_ump:
		_request_production_consent()
	else:
		_initialize_ads()


func _request_production_consent() -> void:
	_boot_state = BootState.CONSENT
	var consent_information_script = load("res://addons/admob/gdscript/src/ump/api/ConsentInformation.gd")
	_consent_information = consent_information_script.new()
	_consent_information.update(
		_create_consent_request_parameters(),
		_on_consent_information_updated,
		func(_error): _on_consent_failed()
	)


func _create_consent_request_parameters():
	var parameters = load("res://addons/admob/gdscript/src/ump/core/ConsentRequestParameters.gd").new()
	if _is_test_build:
		var debug_settings = load("res://addons/admob/gdscript/src/ump/core/ConsentDebugSettings.gd").new()
		var debug_geography = load("res://addons/admob/gdscript/src/ump/core/DebugGeography.gd")
		debug_settings.debug_geography = debug_geography.Values.NOT_EEA
		debug_settings.test_device_hashed_ids.append(MonetizationConfig.UMP_TEST_DEVICE_HASHED_ID)
		parameters.consent_debug_settings = debug_settings
	return parameters


func _on_consent_information_updated() -> void:
	if _boot_state != BootState.CONSENT:
		return
	var consent_information_script = load("res://addons/admob/gdscript/src/ump/api/ConsentInformation.gd")
	var status = _consent_information.get_consent_status()
	if status == consent_information_script.ConsentStatus.NOT_REQUIRED or status == consent_information_script.ConsentStatus.OBTAINED:
		_on_consent_granted()
	elif status == consent_information_script.ConsentStatus.REQUIRED and _consent_information.get_is_consent_form_available():
		var user_messaging_platform = load("res://addons/admob/gdscript/src/ump/api/UserMessagingPlatform.gd")
		user_messaging_platform.load_consent_form(
			func(form): form.show(_on_consent_form_dismissed),
			func(_error): _on_consent_failed()
		)
	else:
		_on_consent_denied()


func _on_consent_form_dismissed(error) -> void:
	if _boot_state != BootState.CONSENT:
		return
	if error != null:
		_on_consent_failed()
		return
	var consent_information_script = load("res://addons/admob/gdscript/src/ump/api/ConsentInformation.gd")
	var status = _consent_information.get_consent_status()
	if status == consent_information_script.ConsentStatus.NOT_REQUIRED or status == consent_information_script.ConsentStatus.OBTAINED:
		_on_consent_granted()
	else:
		_on_consent_denied()


func _on_consent_granted() -> void:
	if _boot_state == BootState.CONSENT:
		_initialize_ads()


func _on_consent_failed() -> void:
	if _boot_state == BootState.CONSENT:
		_fail_boot()


func _on_consent_denied() -> void:
	if _boot_state == BootState.CONSENT:
		_fail_boot()


func _initialize_ads() -> void:
	_boot_state = BootState.INITIALIZING
	var harness: Variant = _get_harness()
	if harness != null:
		harness.initialize_ads(_on_initialized, _on_initialization_failed)
		return
	var listener = load("res://addons/admob/gdscript/src/api/listeners/OnInitializationCompleteListener.gd").new()
	listener.on_initialization_complete = func(_status): _on_initialized()
	load("res://addons/admob/gdscript/src/api/MobileAds.gd").initialize(listener)


func _on_initialized() -> void:
	if _boot_state != BootState.INITIALIZING:
		return
	_boot_state = BootState.READY
	if _request_type != "":
		_load_request()


func _on_initialization_failed() -> void:
	if _boot_state == BootState.INITIALIZING:
		_fail_boot()


func _fail_boot() -> void:
	_boot_state = BootState.FAILED
	if _request_type != "":
		_finish_failure(_request_id)


func _load_request() -> void:
	var token := _request_id
	if _request_type == "rewarded":
		_load_rewarded(token)
	else:
		_load_interstitial(token)


func _load_rewarded(token: int) -> void:
	var harness: Variant = _get_harness()
	if harness != null:
		harness.load_rewarded_ad(
			func(): _on_rewarded_loaded(null, token),
			func(): _finish_failure(token)
		)
		return
	var callback = load("res://addons/admob/gdscript/src/api/listeners/RewardedAdLoadCallback.gd").new()
	callback.on_ad_loaded = func(ad): _on_rewarded_loaded(ad, token)
	callback.on_ad_failed_to_load = func(_error): _finish_failure(token)
	load("res://addons/admob/gdscript/src/api/RewardedAdLoader.gd").new().load(
		_rewarded_id,
		load("res://addons/admob/gdscript/src/api/core/AdRequest.gd").new(),
		callback
	)


func _on_rewarded_loaded(ad, token: int) -> void:
	if not _is_active(token, "rewarded"):
		_destroy_ad(ad)
		return
	_rewarded_ad = ad
	var harness: Variant = _get_harness()
	if harness != null:
		harness.show_rewarded_ad(
			func(): _finish_reward_success(token),
			func(): _finish_failure(token),
			func(): _finish_failure(token)
		)
		return
	var full_screen_callback = load("res://addons/admob/gdscript/src/api/listeners/FullScreenContentCallback.gd").new()
	full_screen_callback.on_ad_dismissed_full_screen_content = func(): _finish_failure(token)
	full_screen_callback.on_ad_failed_to_show_full_screen_content = func(_error): _finish_failure(token)
	_rewarded_ad.full_screen_content_callback = full_screen_callback
	var reward_listener = load("res://addons/admob/gdscript/src/api/listeners/OnUserEarnedRewardListener.gd").new()
	reward_listener.on_user_earned_reward = func(_reward): _finish_reward_success(token)
	_rewarded_ad.show(reward_listener)


func _load_interstitial(token: int) -> void:
	var harness: Variant = _get_harness()
	if harness != null:
		harness.load_interstitial_ad(
			func(): _on_interstitial_loaded(null, token),
			func(): _finish_failure(token)
		)
		return
	var callback = load("res://addons/admob/gdscript/src/api/listeners/InterstitialAdLoadCallback.gd").new()
	callback.on_ad_loaded = func(ad): _on_interstitial_loaded(ad, token)
	callback.on_ad_failed_to_load = func(_error): _finish_failure(token)
	load("res://addons/admob/gdscript/src/api/InterstitialAdLoader.gd").new().load(
		_interstitial_id,
		load("res://addons/admob/gdscript/src/api/core/AdRequest.gd").new(),
		callback
	)


func _on_interstitial_loaded(ad, token: int) -> void:
	if not _is_active(token, "interstitial"):
		_destroy_ad(ad)
		return
	_interstitial_ad = ad
	var harness: Variant = _get_harness()
	if harness != null:
		harness.show_interstitial_ad(
			func(): _finish_failure(token),
			func(): _finish_failure(token)
		)
		return
	var full_screen_callback = load("res://addons/admob/gdscript/src/api/listeners/FullScreenContentCallback.gd").new()
	full_screen_callback.on_ad_dismissed_full_screen_content = func(): _finish_failure(token)
	full_screen_callback.on_ad_failed_to_show_full_screen_content = func(_error): _finish_failure(token)
	_interstitial_ad.full_screen_content_callback = full_screen_callback
	_interstitial_ad.show()


func _finish_reward_success(token: int) -> void:
	if not _is_active(token, "rewarded"):
		return
	var kind := _reward_kind
	_clear_request()
	reward_earned.emit(kind)


func _finish_failure(token: int) -> void:
	if not _is_active(token, _request_type):
		return
	var type := _request_type
	var kind := _reward_kind
	_clear_request()
	if type == "rewarded":
		reward_failed.emit(kind)
	else:
		interstitial_finished.emit()


func _is_active(token: int, type: String) -> bool:
	return token == _request_id and _request_type == type and type != ""


func _get_harness() -> Variant:
	return _harness.get_ref() if _harness != null else null


func _clear_request() -> void:
	_request_type = ""
	_reward_kind = ""
	_destroy_ad(_rewarded_ad)
	_destroy_ad(_interstitial_ad)
	_rewarded_ad = null
	_interstitial_ad = null


func _destroy_ad(ad) -> void:
	if ad != null and ad.has_method("destroy"):
		ad.destroy()
