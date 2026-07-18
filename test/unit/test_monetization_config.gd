extends "res://addons/gut/test.gd"

const MonetizationConfig = preload("res://scripts/monetization_config.gd")

const DEMO_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const DEMO_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const DEMO_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"

const LIVE_APP_ID := "ca-app-pub-1234567890123456~1234567890"
const LIVE_REWARDED_ID := "ca-app-pub-1234567890123456/1111111111"
const LIVE_INTERSTITIAL_ID := "ca-app-pub-1234567890123456/2222222222"

const POING_SINGLETONS := [

	"PoingGodotAdMob",
	"PoingGodotAdMobRewardedAd",
	"PoingGodotAdMobInterstitialAd",
	"PoingGodotAdMobUserMessagingPlatform",
	"PoingGodotAdMobConsentInformation",
]


func test_android_headless_always_uses_stub() -> void:
	assert_eq(_resolve(true, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")


func test_desktop_always_uses_stub() -> void:
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID, "desktop"), "STUB")


func test_pipe_test_always_uses_stub() -> void:
	assert_eq(_resolve(false, true, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")


func test_android_without_feature_uses_stub() -> void:
	assert_eq(_resolve(false, false, [], POING_SINGLETONS, LIVE_APP_ID, LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")


func test_conflicting_ad_features_use_stub() -> void:
	assert_eq(_resolve(false, false, ["admob_test", "admob_live"], POING_SINGLETONS, DEMO_APP_ID, DEMO_REWARDED_ID, DEMO_INTERSTITIAL_ID), "STUB")


func test_missing_required_native_singleton_uses_stub() -> void:
	var missing_one := POING_SINGLETONS.duplicate()
	missing_one.erase("PoingGodotAdMobInterstitialAd")
	assert_eq(_resolve(false, false, ["admob_test"], missing_one, DEMO_APP_ID, DEMO_REWARDED_ID, DEMO_INTERSTITIAL_ID), "STUB")


func test_test_mode_rejects_non_demo_ids() -> void:
	assert_eq(_resolve(false, false, ["admob_test"], POING_SINGLETONS, LIVE_APP_ID, DEMO_REWARDED_ID, DEMO_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_test"], POING_SINGLETONS, DEMO_APP_ID, LIVE_REWARDED_ID, DEMO_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_test"], POING_SINGLETONS, DEMO_APP_ID, DEMO_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")


func test_test_mode_accepts_exact_google_demo_ids() -> void:
	assert_eq(_resolve(false, false, ["admob_test"], POING_SINGLETONS, DEMO_APP_ID, DEMO_REWARDED_ID, DEMO_INTERSTITIAL_ID), "TEST")


func test_live_mode_rejects_blank_ids() -> void:
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, "", LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, "", LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, LIVE_REWARDED_ID, ""), "STUB")


func test_live_mode_rejects_any_google_demo_id() -> void:
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, DEMO_APP_ID, LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, DEMO_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, LIVE_REWARDED_ID, DEMO_INTERSTITIAL_ID), "STUB")


func test_live_mode_rejects_google_demo_publisher_in_every_id_position() -> void:
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, "ca-app-pub-3940256099942544~1234567890", LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, "ca-app-pub-3940256099942544/6300978111", LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, LIVE_REWARDED_ID, "ca-app-pub-3940256099942544/5354046379"), "STUB")


func test_live_mode_accepts_three_non_demo_ids() -> void:
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "LIVE")


func test_live_mode_rejects_noncanonical_ids() -> void:
	var invalid_ids := [
		"foo",
		" ",
		" %s" % LIVE_APP_ID,
		"%s " % LIVE_REWARDED_ID,
		"ca-app-pub-123456789012345~1234567890",
		"ca-app-pub-1234567890123456~123456789",
		"ca-app-pub-1234567890123456/1234567890",
		"ca-app-pub-1234567890123456/1234567890",
	]
	for invalid_id in invalid_ids:
		assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, invalid_id, LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB", invalid_id)


func test_live_mode_rejects_non_string_ids() -> void:
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, null, LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, 123, LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, {}, LIVE_INTERSTITIAL_ID), "STUB")


func test_live_mode_rejects_mixed_triples_with_one_malformed_id() -> void:
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, "foo", LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, " %s" % LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, LIVE_REWARDED_ID, "%s " % LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, "ca-app-pub-1234567890123456~1234567890", LIVE_INTERSTITIAL_ID), "STUB")
	assert_eq(_resolve(false, false, ["admob_live"], POING_SINGLETONS, LIVE_APP_ID, LIVE_REWARDED_ID, "ca-app-pub-1234567890123456~1234567890"), "STUB")


func test_default_export_selection_disables_ads() -> void:
	var selection: Dictionary = MonetizationConfig.resolve_export_ads_selection("")
	assert_eq(selection.mode, "STUB")
	assert_false(selection.ads_enabled)
	assert_eq(selection.app_id, "")


func test_test_export_selection_uses_exact_google_demo_ids() -> void:
	var selection: Dictionary = MonetizationConfig.resolve_export_ads_selection("Test")
	assert_eq(selection.mode, "TEST")
	assert_true(selection.ads_enabled)
	assert_eq(selection.app_id, DEMO_APP_ID)
	assert_eq(selection.rewarded_id, DEMO_REWARDED_ID)
	assert_eq(selection.interstitial_id, DEMO_INTERSTITIAL_ID)


func test_live_export_selection_rejects_incomplete_malformed_or_demo_ids() -> void:
	assert_false(MonetizationConfig.resolve_export_ads_selection("Live").ads_enabled)
	assert_false(MonetizationConfig.resolve_export_ads_selection("Live", " ", LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID).ads_enabled)
	assert_false(MonetizationConfig.resolve_export_ads_selection("Live", LIVE_APP_ID, "bad", LIVE_INTERSTITIAL_ID).ads_enabled)
	assert_false(MonetizationConfig.resolve_export_ads_selection("Live", DEMO_APP_ID, LIVE_REWARDED_ID, LIVE_INTERSTITIAL_ID).ads_enabled)


func test_valid_live_export_and_runtime_share_one_app_id() -> void:
	var selection: Dictionary = MonetizationConfig.resolve_export_ads_selection(
		"Live",
		LIVE_APP_ID,
		LIVE_REWARDED_ID,
		LIVE_INTERSTITIAL_ID
	)
	assert_eq(selection.mode, "LIVE")
	assert_true(selection.ads_enabled)
	assert_eq(selection.app_id, LIVE_APP_ID)
	assert_eq(selection.app_id, selection.runtime_app_id)
	assert_eq(selection.app_id, selection.manifest_app_id)


func _resolve(
	headless: bool,
	pipe_test: bool,
	features: Array,
	native_singletons: Array,
	app_id: Variant,
	rewarded_id: Variant,
	interstitial_id: Variant,
	platform: String = "android"
) -> String:
	var config = MonetizationConfig.new()
	return config.resolve_ad_mode({
		"platform": platform,
		"headless": headless,
		"pipe_test": pipe_test,
		"custom_features": features,
		"native_singletons": native_singletons,
		"app_id": app_id,
		"rewarded_id": rewarded_id,
		"interstitial_id": interstitial_id,
	})
