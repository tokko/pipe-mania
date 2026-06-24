extends Node
## Services autoload: monetization + leaderboard behind named interfaces, with no-op STUBS as the
## default impl (design). Each stub method ONLY records last_call and returns — no AdMob/IAP SDK,
## no HTTPRequest, no account/network path is constructed (acceptance #3, structural). Live wiring
## is the deferred manual milestone (needs human accounts).

class AdServiceStub:
	var last_call: String = ""
	func show_rewarded(kind: String) -> void:
		last_call = "rewarded:" + kind
	func show_interstitial() -> void:
		last_call = "interstitial"


class IapServiceStub:
	var last_call: String = ""
	func purchase_remove_ads() -> void:
		last_call = "remove_ads"
	func purchase_cosmetic(id: String) -> void:
		last_call = "cosmetic:" + id


class LeaderboardServiceStub:
	var last_call: String = ""
	func submit_score(score: int) -> void:
		last_call = "submit:" + str(score)


var ad := AdServiceStub.new()
var iap := IapServiceStub.new()
var leaderboard := LeaderboardServiceStub.new()
