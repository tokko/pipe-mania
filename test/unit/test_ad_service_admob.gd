extends "res://addons/gut/test.gd"

const AdServiceAdmob = preload("res://scripts/ad_service_admob.gd")
const Services = preload("res://scripts/services.gd")
const DebugGeography = preload("res://addons/admob/gdscript/src/ump/core/DebugGeography.gd")


class FakePoingHarness:
	var calls: Array[String] = []
	var forbidden_legacy_calls: Array[String] = []
	var consent_request_parameters
	var _consent_granted: Callable = Callable()
	var _consent_failed: Callable = Callable()
	var _consent_denied: Callable = Callable()
	var _initialized: Callable = Callable()
	var _initialization_failed: Callable = Callable()
	var _rewarded_loaded: Callable = Callable()
	var _rewarded_load_failed: Callable = Callable()
	var _rewarded_earned: Callable = Callable()
	var _rewarded_dismissed: Callable = Callable()
	var _rewarded_show_failed: Callable = Callable()
	var _interstitial_loaded: Callable = Callable()
	var _interstitial_load_failed: Callable = Callable()
	var _interstitial_dismissed: Callable = Callable()
	var _interstitial_show_failed: Callable = Callable()

	func request_consent(parameters, on_granted: Callable, on_failed: Callable, on_denied: Callable) -> void:
		calls.append("consent")
		consent_request_parameters = parameters
		_consent_granted = on_granted
		_consent_failed = on_failed
		_consent_denied = on_denied

	func initialize_ads(on_initialized: Callable, on_failed: Callable) -> void:
		calls.append("initialize")
		_initialized = on_initialized
		_initialization_failed = on_failed

	func load_rewarded_ad(on_loaded: Callable, on_failed: Callable) -> void:
		calls.append("load_rewarded_ad")
		_rewarded_loaded = on_loaded
		_rewarded_load_failed = on_failed

	func load_rewarded(on_loaded: Callable, on_failed: Callable, _on_rewarded: Callable) -> void:
		forbidden_legacy_calls.append("load_rewarded")
		on_failed.call()

	func show_rewarded_ad(on_earned: Callable, on_dismissed: Callable, on_failed: Callable) -> void:
		calls.append("show_rewarded_ad")
		_rewarded_earned = on_earned
		_rewarded_dismissed = on_dismissed
		_rewarded_show_failed = on_failed

	func load_interstitial_ad(on_loaded: Callable, on_failed: Callable) -> void:
		calls.append("load_interstitial_ad")
		_interstitial_loaded = on_loaded
		_interstitial_load_failed = on_failed

	func load_interstitial(on_loaded: Callable, on_failed: Callable) -> void:
		forbidden_legacy_calls.append("load_interstitial")
		on_failed.call()

	func show_interstitial_ad(on_dismissed: Callable, on_failed: Callable) -> void:
		calls.append("show_interstitial_ad")
		_interstitial_dismissed = on_dismissed
		_interstitial_show_failed = on_failed

	func grant_consent() -> void:
		if _consent_granted.is_valid():
			_consent_granted.call()

	func fail_consent() -> void:
		if _consent_failed.is_valid():
			_consent_failed.call()

	func deny_consent() -> void:
		if _consent_denied.is_valid():
			_consent_denied.call()

	func complete_initialization() -> void:
		if _initialized.is_valid():
			_initialized.call()

	func fail_initialization() -> void:
		if _initialization_failed.is_valid():
			_initialization_failed.call()

	func complete_rewarded_load() -> void:
		if _rewarded_loaded.is_valid():
			_rewarded_loaded.call()

	func fail_rewarded_load() -> void:
		if _rewarded_load_failed.is_valid():
			_rewarded_load_failed.call()

	func earn_reward() -> void:
		if _rewarded_earned.is_valid():
			_rewarded_earned.call()

	func dismiss_rewarded() -> void:
		if _rewarded_dismissed.is_valid():
			_rewarded_dismissed.call()

	func fail_rewarded_show() -> void:
		if _rewarded_show_failed.is_valid():
			_rewarded_show_failed.call()

	func complete_interstitial_load() -> void:
		if _interstitial_loaded.is_valid():
			_interstitial_loaded.call()

	func fail_interstitial_load() -> void:
		if _interstitial_load_failed.is_valid():
			_interstitial_load_failed.call()

	func dismiss_interstitial() -> void:
		if _interstitial_dismissed.is_valid():
			_interstitial_dismissed.call()

	func fail_interstitial_show() -> void:
		if _interstitial_show_failed.is_valid():
			_interstitial_show_failed.call()


func test_consent_precedes_initialize_and_load() -> void:
	var harness := FakePoingHarness.new()
	var adapter = AdServiceAdmob.new(harness, "rewarded-id", "interstitial-id")

	adapter.show_rewarded("revive")
	assert_eq(harness.calls, ["consent"])

	harness.grant_consent()
	assert_eq(harness.calls, ["consent", "initialize"])
	harness.complete_initialization()
	assert_eq(harness.calls, ["consent", "initialize", "load_rewarded_ad"])
	harness.complete_rewarded_load()
	assert_eq(harness.calls, ["consent", "initialize", "load_rewarded_ad", "show_rewarded_ad"])


func test_interstitial_request_does_not_replace_active_rewarded_request() -> void:
	var harness := FakePoingHarness.new()
	var adapter = AdServiceAdmob.new(harness)
	var earned := []
	var failed := []
	var interstitial_finished := []
	adapter.reward_earned.connect(func(kind): earned.append(kind))
	adapter.reward_failed.connect(func(kind): failed.append(kind))
	adapter.interstitial_finished.connect(func(): interstitial_finished.append(true))

	adapter.show_rewarded("revive")
	adapter.show_interstitial()
	assert_eq(harness.calls, ["consent"])
	assert_eq(failed, [])
	assert_eq(interstitial_finished, [])

	harness.grant_consent()
	harness.complete_initialization()
	harness.complete_rewarded_load()
	harness.earn_reward()

	assert_eq(harness.calls, ["consent", "initialize", "load_rewarded_ad", "show_rewarded_ad"])
	assert_eq(earned, ["revive"])
	assert_eq(failed, [])
	assert_eq(interstitial_finished, [])


func test_rewarded_request_does_not_replace_active_interstitial_request() -> void:
	var harness := FakePoingHarness.new()
	var adapter = AdServiceAdmob.new(harness)
	var earned := []
	var failed := []
	var interstitial_finished := []
	adapter.reward_earned.connect(func(kind): earned.append(kind))
	adapter.reward_failed.connect(func(kind): failed.append(kind))
	adapter.interstitial_finished.connect(func(): interstitial_finished.append(true))

	adapter.show_interstitial()
	adapter.show_rewarded("revive")
	assert_eq(harness.calls, ["consent"])
	assert_eq(earned, [])
	assert_eq(interstitial_finished, [])

	harness.grant_consent()
	harness.complete_initialization()
	harness.complete_interstitial_load()
	harness.dismiss_interstitial()

	assert_eq(harness.calls, ["consent", "initialize", "load_interstitial_ad", "show_interstitial_ad"])
	assert_eq(earned, [])
	assert_eq(failed, [])
	assert_eq(interstitial_finished, [true])


func test_test_factory_registers_device_for_not_eea_consent_debug_geography() -> void:
	var harness := FakePoingHarness.new()
	var adapter = Services.create_ad_service("TEST", "rewarded-id", "interstitial-id", harness)

	adapter.show_rewarded("revive")

	assert_not_null(harness.consent_request_parameters)
	if harness.consent_request_parameters == null:
		return
	assert_not_null(harness.consent_request_parameters.consent_debug_settings)
	assert_eq(
		harness.consent_request_parameters.consent_debug_settings.debug_geography,
		DebugGeography.Values.NOT_EEA
	)
	assert_eq(
		harness.consent_request_parameters.consent_debug_settings.test_device_hashed_ids,
		["71DA107F6DC7F38FD723AD65ACE5D574"]
	)


func test_live_factory_leaves_consent_debug_geography_disabled() -> void:
	var harness := FakePoingHarness.new()
	var adapter = Services.create_ad_service("LIVE", "rewarded-id", "interstitial-id", harness)

	adapter.show_rewarded("revive")

	assert_not_null(harness.consent_request_parameters)
	if harness.consent_request_parameters == null:
		return
	assert_null(harness.consent_request_parameters.consent_debug_settings)


func test_production_does_not_use_legacy_loader_interface() -> void:
	var rewarded_harness := FakePoingHarness.new()
	var rewarded_adapter = AdServiceAdmob.new(rewarded_harness)
	rewarded_adapter.show_rewarded("revive")
	rewarded_harness.grant_consent()
	rewarded_harness.complete_initialization()

	var interstitial_harness := FakePoingHarness.new()
	var interstitial_adapter = AdServiceAdmob.new(interstitial_harness)
	interstitial_adapter.show_interstitial()
	interstitial_harness.grant_consent()
	interstitial_harness.complete_initialization()

	assert_eq(rewarded_harness.forbidden_legacy_calls, [], "production must use load_rewarded_ad, not legacy load_rewarded")
	assert_eq(interstitial_harness.forbidden_legacy_calls, [], "production must use load_interstitial_ad, not legacy load_interstitial")


func test_consent_failure_emits_reward_failed_once_and_no_load() -> void:
	var harness := FakePoingHarness.new()
	var adapter = AdServiceAdmob.new(harness)
	var failed := []
	assert_true(adapter.has_signal("reward_failed"), "adapter exposes rewarded failure")
	if adapter.has_signal("reward_failed"):
		adapter.reward_failed.connect(func(kind): failed.append(kind))

	adapter.show_rewarded("revive")
	harness.fail_consent()
	harness.grant_consent()

	assert_eq(failed, ["revive"])
	assert_eq(harness.calls, ["consent"])


func test_consent_denial_emits_interstitial_finished_once_and_no_load() -> void:
	var harness := FakePoingHarness.new()
	var adapter = AdServiceAdmob.new(harness)
	var finished := []
	assert_true(adapter.has_signal("interstitial_finished"), "adapter exposes interstitial completion")
	if adapter.has_signal("interstitial_finished"):
		adapter.interstitial_finished.connect(func(): finished.append(true))

	adapter.show_interstitial()
	harness.deny_consent()
	harness.grant_consent()

	assert_eq(finished, [true])
	assert_eq(harness.calls, ["consent"])


func test_reward_callback_wins_once_and_late_dismissal_is_ignored() -> void:
	var harness := _ready_for_rewarded()
	var adapter = harness.adapter
	var earned := []
	var failed := []
	adapter.reward_earned.connect(func(kind): earned.append(kind))
	assert_true(adapter.has_signal("reward_failed"), "adapter exposes rewarded failure")
	if adapter.has_signal("reward_failed"):
		adapter.reward_failed.connect(func(kind): failed.append(kind))

	harness.harness.earn_reward()
	harness.harness.dismiss_rewarded()
	harness.harness.fail_rewarded_show()

	assert_eq(earned, ["revive"])
	assert_eq(failed, [])


func test_rewarded_dismissal_emits_reward_failed_once() -> void:
	var harness := _ready_for_rewarded()
	var failed := []
	assert_true(harness.adapter.has_signal("reward_failed"), "adapter exposes rewarded failure")
	if harness.adapter.has_signal("reward_failed"):
		harness.adapter.reward_failed.connect(func(kind): failed.append(kind))

	harness.harness.dismiss_rewarded()

	assert_eq(failed, ["revive"])


func test_rewarded_load_failure_emits_reward_failed_once() -> void:
	var harness := _consented_request("rewarded")
	var failed := []
	assert_true(harness.adapter.has_signal("reward_failed"), "adapter exposes rewarded failure")
	if harness.adapter.has_signal("reward_failed"):
		harness.adapter.reward_failed.connect(func(kind): failed.append(kind))

	harness.harness.fail_rewarded_load()

	assert_eq(failed, ["revive"])


func test_rewarded_show_failure_emits_reward_failed_once() -> void:
	var harness := _ready_for_rewarded()
	var failed := []
	assert_true(harness.adapter.has_signal("reward_failed"), "adapter exposes rewarded failure")
	if harness.adapter.has_signal("reward_failed"):
		harness.adapter.reward_failed.connect(func(kind): failed.append(kind))

	harness.harness.fail_rewarded_show()

	assert_eq(failed, ["revive"])


func test_interstitial_dismissal_emits_interstitial_finished_once() -> void:
	var harness := _ready_for_interstitial()
	var finished := []
	assert_true(harness.adapter.has_signal("interstitial_finished"), "adapter exposes interstitial completion")
	if harness.adapter.has_signal("interstitial_finished"):
		harness.adapter.interstitial_finished.connect(func(): finished.append(true))

	harness.harness.dismiss_interstitial()
	harness.harness.fail_interstitial_show()
	harness.harness.dismiss_interstitial()

	assert_eq(finished, [true])


func test_interstitial_load_failure_emits_interstitial_finished_once() -> void:
	var harness := _consented_request("interstitial")
	var finished := []
	assert_true(harness.adapter.has_signal("interstitial_finished"), "adapter exposes interstitial completion")
	if harness.adapter.has_signal("interstitial_finished"):
		harness.adapter.interstitial_finished.connect(func(): finished.append(true))

	harness.harness.fail_interstitial_load()

	assert_eq(finished, [true])


func test_interstitial_show_failure_emits_interstitial_finished_once() -> void:
	var harness := _ready_for_interstitial()
	var finished := []
	assert_true(harness.adapter.has_signal("interstitial_finished"), "adapter exposes interstitial completion")
	if harness.adapter.has_signal("interstitial_finished"):
		harness.adapter.interstitial_finished.connect(func(): finished.append(true))

	harness.harness.fail_interstitial_show()

	assert_eq(finished, [true])


func _ready_for_rewarded() -> Dictionary:
	return _consented_request("rewarded")


func _ready_for_interstitial() -> Dictionary:
	return _consented_request("interstitial")


func _consented_request(kind: String) -> Dictionary:
	var harness := FakePoingHarness.new()
	var adapter = AdServiceAdmob.new(harness)
	if kind == "rewarded":
		adapter.show_rewarded("revive")
	else:
		adapter.show_interstitial()
	harness.grant_consent()
	harness.complete_initialization()
	if kind == "rewarded":
		harness.complete_rewarded_load()
	else:
		harness.complete_interstitial_load()
	return {"harness": harness, "adapter": adapter}
