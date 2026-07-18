extends "res://addons/gut/test.gd"

const Services = preload("res://scripts/services.gd")
const AdServiceAdmob = preload("res://scripts/ad_service_admob.gd")
const SaveStore = preload("res://scripts/save_store.gd")


func test_stub_interstitial_finished_is_deferred() -> void:
	var ad = Services.AdServiceStub.new()
	var finished := []
	assert_true(ad.has_signal("interstitial_finished"), "stub exposes the shared interstitial terminal signal")
	if ad.has_signal("interstitial_finished"):
		ad.interstitial_finished.connect(func(): finished.append(true))

	ad.show_interstitial()

	assert_eq(finished, [], "interstitial completion is not synchronous")
	await get_tree().process_frame
	assert_eq(finished, [true], "stub completes an interstitial on the next idle")


func test_stub_rewarded_success_is_deferred_without_failure() -> void:
	var ad = Services.AdServiceStub.new()
	var earned := []
	var failed := []
	ad.reward_earned.connect(func(kind): earned.append(kind))
	assert_true(ad.has_signal("reward_failed"), "stub exposes the shared rewarded failure signal")
	if ad.has_signal("reward_failed"):
		ad.reward_failed.connect(func(kind): failed.append(kind))

	ad.show_rewarded("revive")

	assert_eq(earned, [], "reward success is not synchronous")
	assert_eq(failed, [], "successful rewarded ads do not fail")
	await get_tree().process_frame
	assert_eq(earned, ["revive"])
	assert_eq(failed, [])


func test_ad_stub_records_calls() -> void:
	var ad = Services.AdServiceStub.new()
	assert_eq(ad.last_call, "", "fresh stub records nothing (control)")
	ad.show_rewarded("revive")
	assert_eq(ad.last_call, "rewarded:revive")
	ad.show_interstitial()
	assert_eq(ad.last_call, "interstitial")


func test_leaderboard_stub_records_call() -> void:
	var lb = Services.LeaderboardServiceStub.new()
	assert_eq(lb.last_call, "", "fresh stub records nothing (control)")
	lb.submit_score(7)
	assert_eq(lb.last_call, "submit:7")


func test_leaderboard_get_top_sorted_and_capped() -> void:
	SaveStore.clear_leaderboard()
	for s in [3, 9, 1, 7]:
		SaveStore.add_leaderboard_entry("AAA", s)
	var lb = Services.LeaderboardServiceStub.new()
	var top2 = lb.get_top(2)
	assert_eq(top2.size(), 2, "get_top(n) returns at most n")
	assert_eq(int(top2[0]["score"]), 9, "get_top is sorted desc (highest first)")


func test_ad_factory_selects_admob_for_test_and_stub_for_stub() -> void:
	var test_ad = Services.create_ad_service(
		"TEST",
		"test-rewarded-id",
		"test-interstitial-id",
		RefCounted.new()
	)
	assert_true(test_ad is AdServiceAdmob, "TEST mode creates the AdMob adapter")

	var stub_ad = Services.create_ad_service("STUB", "", "", RefCounted.new())
	assert_true(stub_ad is Services.AdServiceStub, "STUB mode keeps the deterministic stub")
