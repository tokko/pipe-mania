extends "res://addons/gut/test.gd"
## E7b — Ad/IAP/Leaderboard no-op stubs record their call and construct no live path.

const Services = preload("res://scripts/services.gd")


func test_ad_stub_records_calls() -> void:
	var ad = Services.AdServiceStub.new()
	assert_eq(ad.last_call, "", "fresh stub records nothing (control)")
	ad.show_rewarded("revive")
	assert_eq(ad.last_call, "rewarded:revive")
	ad.show_interstitial()
	assert_eq(ad.last_call, "interstitial")


func test_iap_stub_records_calls() -> void:
	var iap = Services.IapServiceStub.new()
	iap.purchase_remove_ads()
	assert_eq(iap.last_call, "remove_ads")
	iap.purchase_cosmetic("hat")
	assert_eq(iap.last_call, "cosmetic:hat")


func test_leaderboard_stub_records_call() -> void:
	var lb = Services.LeaderboardServiceStub.new()
	assert_eq(lb.last_call, "", "fresh stub records nothing (control)")
	lb.submit_score(7)
	assert_eq(lb.last_call, "submit:7")
