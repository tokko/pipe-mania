extends Node
## Screen-flow controller (mounted only on the non-test branch of Main): SPLASH -> MENU -> GAME ->
## RUNOVER, plus modal overlays (leaderboard / settings). Owns the non-game screen views + the
## modal slot; delegates the game lifecycle to Main (start_game / teardown_game / request_revive /
## purchase_remove_ads). It is the only thing that reads SaveStore for the views, so the views stay
## pure (observe + emit). The headless gate never instantiates this node.

const SplashView = preload("res://scripts/view/splash_view.gd")
const MenuView = preload("res://scripts/view/menu_view.gd")
const RunoverView = preload("res://scripts/view/runover_view.gd")
const LeaderboardView = preload("res://scripts/view/leaderboard_view.gd")
const SettingsView = preload("res://scripts/view/settings_view.gd")
const SaveStore = preload("res://scripts/save_store.gd")

var _main: Node
var _screen_view: CanvasLayer  # the full non-game screen (splash | menu)
var _overlay: CanvasLayer      # run-over (over the frozen board)
var _modal: CanvasLayer        # leaderboard | settings (topmost)
var _pending_score := 0        # run score awaiting an initials submit


func setup(main: Node) -> void:
	_main = main


func start() -> void:
	_show_splash()


# --- mounts ---

func _swap(slot: CanvasLayer, view: CanvasLayer) -> CanvasLayer:
	if slot != null:
		slot.queue_free()
	if view != null:
		view.connect_view(self)
		_main.add_child(view)
	return view


func _show_splash() -> void:
	_screen_view = _swap(_screen_view, SplashView.new())


func go_menu() -> void:
	_modal = _swap(_modal, null)
	_overlay = _swap(_overlay, null)
	_main.teardown_game()
	var v := MenuView.new()
	v.setup(SaveStore.load_high())
	_screen_view = _swap(_screen_view, v)


func show_runover(run) -> void:
	_pending_score = run.run_score
	var v := RunoverView.new()
	v.setup(run.run_score, run.high_score, _qualifies(run.run_score), not run.revived)
	_overlay = _swap(_overlay, v)


## A score qualifies for the local board if it is positive AND (the board is short OR it beats the
## lowest entry). Mirrors SaveStore's top-10 cap.
func _qualifies(score: int) -> bool:
	if score <= 0:
		return false
	var lb := SaveStore.load_leaderboard()
	if lb.size() < 10:
		return true
	return score > int(lb[lb.size() - 1]["score"])


# --- view signal handlers ---

func _on_splash_dismissed() -> void:
	go_menu()


func _on_menu_play() -> void:
	_screen_view = _swap(_screen_view, null)
	_main.start_game()


func _on_runover_new_game() -> void:
	_overlay = _swap(_overlay, null)
	_main.start_game()


func _on_runover_revive() -> void:
	_overlay = _swap(_overlay, null)
	_main.request_revive()


func _on_runover_menu() -> void:
	go_menu()


func _on_initials_submitted(initials) -> void:
	SaveStore.add_leaderboard_entry(initials, _pending_score)
	Services.leaderboard.submit_score(_pending_score)


func _on_open_leaderboard() -> void:
	var v := LeaderboardView.new()
	v.setup(SaveStore.load_leaderboard())
	_modal = _swap(_modal, v)


func _on_open_settings() -> void:
	var v := SettingsView.new()
	v.setup(Settings.audio_enabled, Settings.ads_removed)
	_modal = _swap(_modal, v)


func _on_close_modal() -> void:
	_modal = _swap(_modal, null)


func _on_settings_audio_toggled() -> void:
	Settings.toggle_audio()


func _on_settings_remove_ads() -> void:
	_main.purchase_remove_ads()


# --- headless gate helper ---

func screen_label() -> String:
	if _modal != null:
		return "MODAL"
	if _overlay != null:
		return "RUNOVER"
	if _screen_view is SplashView:
		return "SPLASH"
	if _screen_view is MenuView:
		return "MENU"
	return "GAME"
