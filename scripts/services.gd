extends Node
## Services autoload: monetization + leaderboard behind named interfaces. The default stubs record
## last_call and emit deferred success signals, so callers use the same async contract in every mode.
## Ads upgrade only after the strict Android environment resolver selects TEST or LIVE.

const MonetizationConfig = preload("res://scripts/monetization_config.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const AdServiceAdmob = preload("res://scripts/ad_service_admob.gd")


class AdServiceStub:
	signal reward_earned(kind: String)
	signal reward_failed(kind: String)
	signal interstitial_finished()
	var last_call: String = ""
	func show_rewarded(kind: String) -> void:
		last_call = "rewarded:" + kind
		reward_earned.emit.call_deferred(kind)  # the stub "completes" the rewarded ad next idle
	func show_interstitial() -> void:
		last_call = "interstitial"
		interstitial_finished.emit.call_deferred()


class LeaderboardServiceStub:
	var last_call: String = ""
	func submit_score(score: int) -> void:
		last_call = "submit:" + str(score)
	## Sync-now read of the local board. An online backend wraps this signal-based later; do not
	## add `await` callers against this signature now.
	func get_top(n: int) -> Array:
		return SaveStore.load_leaderboard().slice(0, n)


# Stub by default (headless/desktop). _ready() upgrades ads only when the resolver permits it.
var ad = AdServiceStub.new()
var leaderboard = LeaderboardServiceStub.new()
var ad_mode: String = "STUB"


static func create_ad_service(mode, rewarded_id: String, interstitial_id: String, harness = null):
	var is_test_mode: bool = (mode is String and mode == "TEST") or (mode is int and mode == MonetizationConfig.AdMode.TEST)
	var is_live_mode: bool = (mode is String and mode == "LIVE") or (mode is int and mode == MonetizationConfig.AdMode.LIVE)
	if is_test_mode or is_live_mode:
		return AdServiceAdmob.new(harness, rewarded_id, interstitial_id, is_test_mode)
	return AdServiceStub.new()


func _ready() -> void:
	var custom_features: Array[String] = []
	if OS.has_feature("admob_test"):
		custom_features.append("admob_test")
	if OS.has_feature("admob_live"):
		custom_features.append("admob_live")
	var native_singletons: Array[String] = []
	for singleton in MonetizationConfig.ADMOB_SINGLETONS:
		if Engine.has_singleton(singleton):
			native_singletons.append(singleton)
	var export_target := ""
	if custom_features == ["admob_test"]:
		export_target = "Test"
	elif custom_features == ["admob_live"]:
		export_target = "Live"
	var selection: Dictionary = MonetizationConfig.resolve_export_ads_selection(export_target)
	ad_mode = MonetizationConfig.new().resolve_ad_mode({
		"platform": OS.get_name().to_lower(),
		"headless": OS.has_feature("headless"),
		"pipe_test": OS.get_environment("PIPE_TEST") != "",
		"custom_features": custom_features,
		"native_singletons": native_singletons,
		"app_id": selection.app_id,
		"rewarded_id": selection.rewarded_id,
		"interstitial_id": selection.interstitial_id,
	})
	if ad_mode != "STUB":
		ad = create_ad_service(
			ad_mode,
			selection.rewarded_id,
			selection.interstitial_id
		)
	# leaderboard stays local (stub) until an online backend exists; the interface is unchanged.
