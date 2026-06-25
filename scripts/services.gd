extends Node
## Services autoload: monetization + leaderboard behind named interfaces. The DEV STUBS (default)
## record last_call and emit DEFERRED success signals, so the dev path mirrors the real async-SDK
## path — callers grant in the signal handler, never right after a fire-and-forget call. At boot,
## _ready() swaps in a *Real adapter per service IFF its Android plugin singleton is present (real
## device with the v2 plugins installed); headless / desktop have no singleton -> the stub stays.
## Live SDK wiring is the deferred manual milestone (see docs/MONETIZATION_SETUP.md).

const MonetizationConfig = preload("res://scripts/monetization_config.gd")
const SaveStore = preload("res://scripts/save_store.gd")


class AdServiceStub:
	signal reward_earned(kind: String)
	var last_call: String = ""
	func show_rewarded(kind: String) -> void:
		last_call = "rewarded:" + kind
		reward_earned.emit.call_deferred(kind)  # the stub "completes" the rewarded ad next idle
	func show_interstitial() -> void:
		last_call = "interstitial"


class IapServiceStub:
	signal purchase_succeeded(product: String)
	var last_call: String = ""
	func purchase_remove_ads() -> void:
		last_call = "remove_ads"
		purchase_succeeded.emit.call_deferred("remove_ads")
	func purchase_cosmetic(id: String) -> void:
		last_call = "cosmetic:" + id
		purchase_succeeded.emit.call_deferred(id)


class LeaderboardServiceStub:
	var last_call: String = ""
	func submit_score(score: int) -> void:
		last_call = "submit:" + str(score)
	## Sync-now read of the local board. An online backend wraps this signal-based later; do not
	## add `await` callers against this signature now.
	func get_top(n: int) -> Array:
		return SaveStore.load_leaderboard().slice(0, n)


# --- Real adapters: only instantiated when the plugin singleton is present (Phase 5 wiring). Bodies
# are intentionally thin shells — they can't be exercised headless and the SDK isn't wired yet; they
# mirror the stub interface so callers don't change when a real adapter takes over.

class AdServiceReal:
	signal reward_earned(kind: String)
	var last_call: String = ""
	var _plugin
	func _init() -> void:
		_plugin = Engine.get_singleton(MonetizationConfig.ADMOB_SINGLETON)
		# TODO(Phase 5): connect the plugin's onUserEarnedReward callback -> reward_earned.emit(kind)
	func show_rewarded(kind: String) -> void:
		last_call = "rewarded:" + kind
		# TODO(Phase 5): load+show rewarded (MonetizationConfig.AD_UNIT_REWARDED); grant ONLY from
		# the SDK reward callback above, never here.
	func show_interstitial() -> void:
		last_call = "interstitial"
		# TODO(Phase 5): show interstitial (MonetizationConfig.AD_UNIT_INTERSTITIAL)


class IapServiceReal:
	signal purchase_succeeded(product: String)
	var last_call: String = ""
	var _plugin
	func _init() -> void:
		_plugin = Engine.get_singleton(MonetizationConfig.BILLING_SINGLETON)
		# TODO(Phase 5): connect the plugin's purchase-acknowledged callback -> purchase_succeeded.emit
	func purchase_remove_ads() -> void:
		last_call = "remove_ads"
		# TODO(Phase 5): start the billing flow (MonetizationConfig.BILLING_PRODUCT_REMOVE_ADS); set
		# ads_removed ONLY from the acknowledged-purchase callback.
	func purchase_cosmetic(id: String) -> void:
		last_call = "cosmetic:" + id


# Stub by default (headless/desktop). _ready() upgrades to a *Real adapter where the plugin exists.
var ad = AdServiceStub.new()
var iap = IapServiceStub.new()
var leaderboard = LeaderboardServiceStub.new()


func _ready() -> void:
	if Engine.has_singleton(MonetizationConfig.ADMOB_SINGLETON):
		ad = AdServiceReal.new()
	if Engine.has_singleton(MonetizationConfig.BILLING_SINGLETON):
		iap = IapServiceReal.new()
	# leaderboard stays local (stub) until an online backend exists; the interface is unchanged.
