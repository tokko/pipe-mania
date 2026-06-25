extends "res://addons/gut/test.gd"
## E7b — Ad/IAP/Leaderboard no-op stubs record their call and construct no live path.

const Services = preload("res://scripts/services.gd")
const SaveStore = preload("res://scripts/save_store.gd")


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


func test_leaderboard_get_top_sorted_and_capped() -> void:  # local read behind the stable interface
	SaveStore.clear_leaderboard()
	for s in [3, 9, 1, 7]:
		SaveStore.add_leaderboard_entry("AAA", s)
	var lb = Services.LeaderboardServiceStub.new()
	var top2 = lb.get_top(2)
	assert_eq(top2.size(), 2, "get_top(n) returns at most n")
	assert_eq(int(top2[0]["score"]), 9, "get_top is sorted desc (highest first)")


func test_ad_stub_emits_reward_deferred() -> void:  # the grant seam fires AFTER last_call is set
	var ad = Services.AdServiceStub.new()
	var got := []
	ad.reward_earned.connect(func(kind): got.append(kind))
	ad.show_rewarded("revive")
	assert_eq(ad.last_call, "rewarded:revive", "last_call is set synchronously (E7b marker intact)")
	assert_eq(got.size(), 0, "reward_earned is deferred, not synchronous")
	await get_tree().process_frame
	assert_eq(got, ["revive"], "reward_earned fires on the next idle")
