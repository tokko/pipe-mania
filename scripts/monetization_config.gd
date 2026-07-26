extends RefCounted

enum AdMode { STUB, TEST, LIVE }
## Monetization config — placeholders until the real IDs are supplied (account-gated; see
## docs/MONETIZATION_SETUP.md). These are NOT secrets: AdMob app/unit IDs and Billing product IDs
## ship in every published APK. The `*Real` Services adapters read the credential consts; the
## singleton-name consts drive the Engine.has_singleton() real-or-stub dispatch in services.gd
## (present on a real device with the v2 plugins -> *Real; absent / headless -> dev stub).

# Android plugin singleton names (the dispatch seam).
const ADMOB_SINGLETON := "PoingGodotAdMob"
const ADMOB_REWARDED_SINGLETON := "PoingGodotAdMobRewardedAd"
const ADMOB_INTERSTITIAL_SINGLETON := "PoingGodotAdMobInterstitialAd"
const ADMOB_UMP_SINGLETON := "PoingGodotAdMobUserMessagingPlatform"
const ADMOB_CONSENT_SINGLETON := "PoingGodotAdMobConsentInformation"
const ADMOB_SINGLETONS := [
	ADMOB_SINGLETON,
	ADMOB_REWARDED_SINGLETON,
	ADMOB_INTERSTITIAL_SINGLETON,
	ADMOB_UMP_SINGLETON,
	ADMOB_CONSENT_SINGLETON,
]
const BILLING_SINGLETON := "GodotGooglePlayBilling"

# Credential placeholders (empty until supplied).
const ADMOB_APP_ID := ""
const AD_UNIT_REWARDED := ""
const AD_UNIT_INTERSTITIAL := ""
const BILLING_PRODUCT_REMOVE_ADS := "remove_ads"

# Google Android test IDs.
const ADMOB_TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const AD_UNIT_REWARDED_TEST := "ca-app-pub-3940256099942544/5224354917"
const AD_UNIT_INTERSTITIAL_TEST := "ca-app-pub-3940256099942544/1033173712"
const GOOGLE_DEMO_PUBLISHER := "3940256099942544"
const UMP_TEST_DEVICE_HASHED_ID := "71DA107F6DC7F38FD723AD65ACE5D574"
const EXPORT_SELECTOR_ENV := "AQUEDUCT_ADS_EXPORT_TARGET"


static func resolve_export_ads_selection(
	target: String,
	live_app_id: String = ADMOB_APP_ID,
	live_rewarded_id: String = AD_UNIT_REWARDED,
	live_interstitial_id: String = AD_UNIT_INTERSTITIAL
) -> Dictionary:
	var selection := {
		"mode": "STUB",
		"ads_enabled": false,
		"app_id": "",
		"rewarded_id": "",
		"interstitial_id": "",
		"runtime_app_id": "",
		"manifest_app_id": "",
	}
	if target == "Test":
		selection = {
			"mode": "TEST",
			"ads_enabled": true,
			"app_id": ADMOB_TEST_APP_ID,
			"rewarded_id": AD_UNIT_REWARDED_TEST,
			"interstitial_id": AD_UNIT_INTERSTITIAL_TEST,
			"runtime_app_id": ADMOB_TEST_APP_ID,
			"manifest_app_id": ADMOB_TEST_APP_ID,
		}
	elif target == "Live" and _is_valid_live_triple(live_app_id, live_rewarded_id, live_interstitial_id):
		selection = {
			"mode": "LIVE",
			"ads_enabled": true,
			"app_id": live_app_id,
			"rewarded_id": live_rewarded_id,
			"interstitial_id": live_interstitial_id,
			"runtime_app_id": live_app_id,
			"manifest_app_id": live_app_id,
		}
	return selection

func resolve_ad_mode(environment: Dictionary) -> String:
	if environment.get("platform", "") != "android":
		return "STUB"
	if environment.get("headless", false) or environment.get("pipe_test", false):
		return "STUB"

	var features = environment.get("custom_features", [])
	var native_singletons = environment.get("native_singletons", [])
	if not features is Array or features.size() != 1 or not native_singletons is Array:
		return "STUB"
	for singleton in ADMOB_SINGLETONS:
		if singleton not in native_singletons:
			return "STUB"

	var app_id = environment.get("app_id", "")
	var rewarded_id = environment.get("rewarded_id", "")
	var interstitial_id = environment.get("interstitial_id", "")
	if features[0] == "admob_test":
		if app_id == ADMOB_TEST_APP_ID and rewarded_id == AD_UNIT_REWARDED_TEST and interstitial_id == AD_UNIT_INTERSTITIAL_TEST:
			return "TEST"
	elif features[0] == "admob_live" and _is_valid_admob_id(app_id, "~") and _is_valid_admob_id(rewarded_id, "/") and _is_valid_admob_id(interstitial_id, "/") and not _uses_google_demo_publisher(app_id, rewarded_id, interstitial_id):
		return "LIVE"
	return "STUB"

static func _is_valid_live_triple(app_id: Variant, rewarded_id: Variant, interstitial_id: Variant) -> bool:
	return (
		_is_valid_admob_id(app_id, "~")
		and _is_valid_admob_id(rewarded_id, "/")
		and _is_valid_admob_id(interstitial_id, "/")
		and not _uses_google_demo_publisher(app_id, rewarded_id, interstitial_id)
	)


static func _is_valid_admob_id(value: Variant, separator: String) -> bool:
	if not value is String:
		return false
	var pattern := "^ca-app-pub-[0-9]{16}%s[0-9]{10}$" % separator
	return RegEx.create_from_string(pattern).search(value) != null

static func _uses_google_demo_publisher(app_id: Variant, rewarded_id: Variant, interstitial_id: Variant) -> bool:
	var publisher_pattern := RegEx.create_from_string("^ca-app-pub-([0-9]{16})[~/][0-9]{10}$")
	for value in [app_id, rewarded_id, interstitial_id]:
		var match_result := publisher_pattern.search(value)
		if match_result != null and match_result.get_string(1) == GOOGLE_DEMO_PUBLISHER:
			return true
	return false
