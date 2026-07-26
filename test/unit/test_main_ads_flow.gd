extends "res://addons/gut/test.gd"

const Main = preload("res://scripts/main.gd")
const GameState = preload("res://scripts/model/game_state.gd")
const Run = preload("res://scripts/model/run.gd")
const HUD = preload("res://scripts/view/hud.gd")


class FakeAdService extends RefCounted:
	signal reward_earned(kind: String)
	signal reward_failed(kind: String)
	signal interstitial_finished()
	var rewarded_requests := 0
	var interstitial_requests := 0

	func show_rewarded(_kind: String) -> void:
		rewarded_requests += 1

	func show_interstitial() -> void:
		interstitial_requests += 1

	func earn_reward(kind: String) -> void:
		reward_earned.emit(kind)

	func fail_reward(kind: String) -> void:
		reward_failed.emit(kind)

	func finish_interstitial() -> void:
		interstitial_finished.emit()


class MainHarness extends Main:
	var mount_count := 0
	var started_modes := []

	func _start_game(mode: int = Run.Mode.EASY) -> void:
		mount_count += 1
		started_modes.append(mode)
		_run = Run.new(7, mode)

	func _mount_board(_game_state) -> void:
		mount_count += 1


var _saved_ad
var _ad: FakeAdService
var _services: Node


func before_each() -> void:
	_services = get_node("/root/Services")
	_saved_ad = _services.ad
	_ad = FakeAdService.new()
	_services.ad = _ad


func after_each() -> void:
	_services.ad = _saved_ad


func _new_main() -> MainHarness:
	var main := MainHarness.new()
	add_child_autoqfree(main)
	main._ui_flow_active = false
	return main


func _complete_current_run(main: MainHarness) -> void:
	if main._hud == null:
		main._hud = HUD.new()
		main.add_child(main._hud)
	main._on_outcome(GameState.Outcome.LEAK, 0)


func _start_and_finish_if_waiting(main: MainHarness, mode: int = Run.Mode.EASY) -> void:
	var mounts_before := main.mount_count
	main.start_game(mode)
	if main.mount_count == mounts_before:
		_ad.finish_interstitial()


func _failed_run(main: MainHarness) -> void:
	main._run = Run.new(7)
	main._run.on_fail(4)
	main._screen.show_runover(main._run, 4)


func test_completed_run_cadence_rows_zero_through_four() -> void:
	var main := _new_main()

	main.start_game()
	assert_eq(_ad.interstitial_requests, 0, "session start is ad-free")
	assert_eq(main.mount_count, 1, "session start mounts immediately")

	_complete_current_run(main)
	var mounts_before := main.mount_count
	main.start_game()
	assert_eq(_ad.interstitial_requests, 0, "after completed run 1 the next start is ad-free")
	assert_eq(main.mount_count, mounts_before + 1, "row 1 mounts immediately")
	if main.mount_count == mounts_before:
		_ad.finish_interstitial()

	_complete_current_run(main)
	mounts_before = main.mount_count
	main.start_game(Run.Mode.MEDIUM)
	assert_eq(_ad.interstitial_requests, 1, "after completed run 2 the next start requests one ad")
	assert_eq(main.mount_count, mounts_before, "row 2 waits for the interstitial terminal")
	main.start_game(Run.Mode.HARD)
	assert_eq(_ad.interstitial_requests, 1, "a duplicate pending start does not request another ad")
	assert_eq(main.mount_count, mounts_before, "a duplicate pending start does not mount")
	_ad.finish_interstitial()
	assert_eq(main.mount_count, mounts_before + 1, "one terminal mounts exactly once")
	_ad.finish_interstitial()
	assert_eq(main.mount_count, mounts_before + 1, "a duplicate terminal is ignored")

	_complete_current_run(main)
	mounts_before = main.mount_count
	main.start_game()
	assert_eq(_ad.interstitial_requests, 1, "after completed run 3 the next start is ad-free")
	assert_eq(main.mount_count, mounts_before + 1, "row 3 mounts immediately")
	if main.mount_count == mounts_before:
		_ad.finish_interstitial()

	_complete_current_run(main)
	mounts_before = main.mount_count
	main.start_game()
	assert_eq(_ad.interstitial_requests, 2, "after completed run 4 the next start requests one ad")
	assert_eq(main.mount_count, mounts_before, "row 4 waits for the interstitial terminal")


func test_abandon_to_menu_does_not_advance_cadence() -> void:
	var main := _new_main()
	main.start_game()
	main.teardown_game()
	main.start_game()

	assert_eq(_ad.interstitial_requests, 0, "abandoning a live run does not count as completion")
	assert_eq(main.mount_count, 2, "the next start after abandon mounts immediately")


func test_revived_run_counts_once_after_second_failure() -> void:
	var main := _new_main()
	main.start_game()
	_complete_current_run(main)
	main.request_revive()
	_ad.earn_reward("revive")
	assert_false(main._run.over, "the logical run resumes after reward")

	_complete_current_run(main)
	var mounts_before := main.mount_count
	main.start_game()
	assert_eq(_ad.interstitial_requests, 0, "the revived run's second failure does not count again")
	assert_eq(main.mount_count, mounts_before + 1, "one completed logical run remains ad-free")


func test_duplicate_terminal_callback_counts_completion_once() -> void:
	var main := _new_main()
	main.start_game()
	_complete_current_run(main)
	_complete_current_run(main)
	var mounts_before := main.mount_count
	main.start_game()

	assert_eq(_ad.interstitial_requests, 0, "duplicate failure callbacks do not advance cadence")
	assert_eq(main.mount_count, mounts_before + 1, "the next start still sees one completion")


func test_interstitial_pending_rejects_revive_request() -> void:
	var main := _new_main()
	_start_and_finish_if_waiting(main)
	_complete_current_run(main)
	_start_and_finish_if_waiting(main)
	_complete_current_run(main)
	main.start_game(Run.Mode.HARD)
	assert_eq(_ad.interstitial_requests, 1, "two completions make the interstitial pending")

	main.request_revive()
	assert_eq(_ad.rewarded_requests, 0, "an interstitial-pending state rejects rewarded revive")


func test_rewarded_pending_rejects_new_game() -> void:
	var main := _new_main()
	_failed_run(main)
	main.request_revive()
	assert_eq(_ad.rewarded_requests, 1, "rewarded revive is pending")

	main.start_game(Run.Mode.HARD)
	assert_eq(_ad.interstitial_requests, 0, "rewarded pending does not start an interstitial")
	assert_eq(main.mount_count, 0, "rewarded pending does not mount a new game")


func test_pending_interstitial_continues_with_selected_mode_after_one_terminal() -> void:
	var main := _new_main()
	_start_and_finish_if_waiting(main)
	_complete_current_run(main)
	_start_and_finish_if_waiting(main)
	_complete_current_run(main)
	var mounts_before := main.mount_count

	main.start_game(Run.Mode.HARD)
	assert_eq(main.mount_count, mounts_before, "eligible selected mode waits for the ad")
	_ad.finish_interstitial()
	assert_eq(main.mount_count, mounts_before + 1, "terminal starts the selected run once")
	assert_eq(main.started_modes[-1], Run.Mode.HARD, "terminal continues with the chosen mode")


func test_failed_reward_keeps_run_over_and_ignores_late_reward() -> void:
	var main := _new_main()
	_failed_run(main)
	main._screen._on_runover_revive()
	main._screen._on_runover_revive()
	assert_eq(_ad.rewarded_requests, 1, "duplicate revive request is ignored")

	_ad.fail_reward("revive")
	await get_tree().process_frame
	assert_true(main._run.over, "failed reward leaves the run over")
	assert_eq(main._screen.screen_label(), "RUNOVER", "failed reward keeps Run Over visible")
	var status := main._screen._overlay.find_child("AdStatus", true, false) as Label
	assert_not_null(status, "Run Over exposes ad status")
	if status != null:
		assert_eq(status.text, "Ad unavailable. Try again.", "failed reward shows the exact error")

	_ad.earn_reward("revive")
	await get_tree().process_frame
	assert_true(main._run.over, "a late reward after failure is ignored")
	assert_eq(main.mount_count, 0, "a late reward does not mount a board")


func test_one_valid_reward_revives_once_and_ignores_duplicate_reward() -> void:
	var main := _new_main()
	_failed_run(main)
	main._screen._on_runover_revive()
	assert_eq(_ad.rewarded_requests, 1)

	_ad.earn_reward("revive")
	await get_tree().process_frame
	assert_false(main._run.over, "a valid reward revives the failed run")
	assert_eq(main.mount_count, 1, "a valid reward mounts the current board once")

	_ad.earn_reward("revive")
	await get_tree().process_frame
	assert_eq(main.mount_count, 1, "a duplicate reward is ignored")
