extends "res://addons/gut/test.gd"
## S4.2 — SaveStore: the single high-score persistence boundary (JSON in user://).

const SaveStore = preload("res://scripts/save_store.gd")


func _clear() -> void:
	var d := DirAccess.open("user://")
	if d and d.file_exists("highscore.json"):
		d.remove("highscore.json")


func test_absent_returns_zero() -> void:
	_clear()
	assert_eq(SaveStore.load_high(), 0, "no save file -> high score 0")


func test_save_then_load_roundtrip() -> void:  # acceptance: high score survives a reload
	_clear()
	SaveStore.save_high(42)
	assert_eq(SaveStore.load_high(), 42, "high score survives a SaveStore reload")


func test_overwrite_keeps_latest() -> void:
	_clear()
	SaveStore.save_high(10)
	SaveStore.save_high(25)
	assert_eq(SaveStore.load_high(), 25, "latest save wins")


func test_tutorial_seen_default_false() -> void:  # E5.1
	_clear()
	assert_false(SaveStore.load_tutorial_seen(), "no save -> tutorial not seen")


func test_tutorial_seen_roundtrip() -> void:  # E5.1
	_clear()
	SaveStore.save_tutorial_seen(true)
	assert_true(SaveStore.load_tutorial_seen())


func test_tutorial_seen_does_not_clobber_high() -> void:  # E5.1 control (read-modify-write)
	_clear()
	SaveStore.save_high(50)
	SaveStore.save_tutorial_seen(true)
	assert_eq(SaveStore.load_high(), 50, "saving tutorial_seen must not wipe the high score")
	assert_true(SaveStore.load_tutorial_seen())


func test_wrong_shape_returns_zero() -> void:  # control (must be able to go red)
	# Valid JSON but not the expected {"high": int} dict -> 0. (Avoids triggering Godot's
	# JSON-parse error log on raw garbage, which would spam the gate's stderr.)
	var f := FileAccess.open("user://highscore.json", FileAccess.WRITE)
	f.store_string("[1, 2, 3]")
	f.close()
	assert_eq(SaveStore.load_high(), 0, "JSON of the wrong shape -> 0, no crash")


# --- Local leaderboard (top-10) ---

func test_leaderboard_absent_returns_empty() -> void:
	_clear()
	assert_eq(SaveStore.load_leaderboard().size(), 0, "no save -> empty leaderboard")


func test_leaderboard_sorts_desc_by_score() -> void:
	_clear()
	SaveStore.add_leaderboard_entry("AAA", 5)
	SaveStore.add_leaderboard_entry("BBB", 20)
	SaveStore.add_leaderboard_entry("CCC", 12)
	var lb := SaveStore.load_leaderboard()
	assert_eq(int(lb[0]["score"]), 20, "highest score first")
	assert_eq(int(lb[1]["score"]), 12)
	assert_eq(int(lb[2]["score"]), 5, "lowest score last")


func test_leaderboard_caps_at_ten_and_drops_lowest() -> void:  # trim must drop the LOWEST entry
	_clear()
	for s in range(1, 12):  # scores 1..11 (11 entries)
		SaveStore.add_leaderboard_entry("X", s)
	var lb := SaveStore.load_leaderboard()
	assert_eq(lb.size(), 10, "leaderboard caps at 10")
	var scores := []
	for e in lb:
		scores.append(int(e["score"]))
	assert_false(scores.has(1), "the lowest score (1) was the one trimmed")
	assert_true(scores.has(11), "the highest score (11) is retained")


func test_leaderboard_initials_clamped_upper() -> void:
	_clear()
	SaveStore.add_leaderboard_entry("abcd", 9)  # too long + lower-case
	assert_eq(SaveStore.load_leaderboard()[0]["name"], "ABC", "name clamped to 3 upper-case chars")


func test_leaderboard_clear_empties() -> void:
	_clear()
	SaveStore.add_leaderboard_entry("AAA", 9)
	SaveStore.clear_leaderboard()
	assert_eq(SaveStore.load_leaderboard().size(), 0, "clear empties the leaderboard")


func test_leaderboard_wrong_shape_returns_empty() -> void:  # control (must be able to go red)
	_clear()
	SaveStore.save_high(7)
	var f := FileAccess.open("user://highscore.json", FileAccess.WRITE)
	f.store_string('{"high": 7, "leaderboard": {"x": 1}}')  # object, not array
	f.close()
	assert_eq(SaveStore.load_leaderboard().size(), 0, "wrong-shape leaderboard -> empty, no crash")


func test_leaderboard_persists_score_and_date() -> void:
	_clear()
	SaveStore.add_leaderboard_entry("AAA", 17, "2026-07-16")
	var entry: Dictionary = SaveStore.load_leaderboard()[0]
	assert_eq(entry["name"], "AAA")
	assert_eq(int(entry["score"]), 17)
	assert_eq(entry["date"], "2026-07-16", "played date survives a reload")


func test_leaderboard_stays_high_to_low_with_dates() -> void:
	_clear()
	SaveStore.add_leaderboard_entry("LOW", 5, "2026-07-14")
	SaveStore.add_leaderboard_entry("HIGH", 20, "2026-07-16")
	SaveStore.add_leaderboard_entry("MID", 12, "2026-07-15")
	var leaderboard := SaveStore.load_leaderboard()
	assert_eq(int(leaderboard[0]["score"]), 20)
	assert_eq(leaderboard[0]["date"], "2026-07-16")
	assert_eq(int(leaderboard[1]["score"]), 12)
	assert_eq(int(leaderboard[2]["score"]), 5)


func test_legacy_leaderboard_entry_without_date_is_retained() -> void:
	_clear()
	var f := FileAccess.open("user://highscore.json", FileAccess.WRITE)
	f.store_string('{"leaderboard": [{"name": "OLD", "score": 8}]}')
	f.close()
	var entry: Dictionary = SaveStore.load_leaderboard()[0]
	assert_eq(entry["name"], "OLD")
	assert_eq(int(entry["score"]), 8)
	assert_false(entry.has("date"), "legacy entry remains readable without invented data")


func test_mixed_legacy_leaderboard_loads_valid_sorted_top_ten_entries() -> void:
	_clear()
	var entries := [
		{"name": "LOW", "score": 10},
		null,
		{"name": "HIGH", "score": 120},
		"not-a-dictionary",
		{"name": "NO_SCORE"},
		{"name": "S110", "score": 110},
		{"name": "S100", "score": 100},
		{"name": "S90", "score": 90},
		{"name": "S80", "score": 80},
		{"name": "S70", "score": 70},
		{"name": "S60", "score": 60},
		{"name": "S50", "score": 50},
		{"name": "S40", "score": 40},
		{"name": "S30", "score": 30},
		{"name": "S20", "score": 20}
	]
	var f := FileAccess.open("user://highscore.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"leaderboard": entries}))
	f.close()

	var leaderboard: Array = SaveStore.load_leaderboard()
	assert_eq(leaderboard.size(), 10, "invalid legacy entries are filtered and valid scores are capped")
	var scores := []
	for entry in leaderboard:
		assert_true(entry is Dictionary, "loaded leaderboard entries are dictionaries")
		if entry is Dictionary and entry.has("score"):
			scores.append(int(entry["score"]))
	assert_eq(scores, [120, 110, 100, 90, 80, 70, 60, 50, 40, 30], "valid scores load highest to lowest")


# --- ads_removed / audio_enabled flags ---

func test_ads_removed_default_false() -> void:
	_clear()
	assert_false(SaveStore.load_ads_removed(), "no save -> ads not removed")


func test_ads_removed_roundtrip() -> void:
	_clear()
	SaveStore.save_ads_removed(true)
	assert_true(SaveStore.load_ads_removed(), "ads_removed survives a reload")


func test_ads_removed_does_not_clobber_high() -> void:  # control (read-modify-write)
	_clear()
	SaveStore.save_high(33)
	SaveStore.save_ads_removed(true)
	assert_eq(SaveStore.load_high(), 33, "saving ads_removed must not wipe the high score")
	assert_true(SaveStore.load_ads_removed())


func test_audio_enabled_default_true() -> void:
	_clear()
	assert_true(SaveStore.load_audio_enabled(), "no save -> audio enabled by default")


func test_audio_enabled_roundtrip() -> void:
	_clear()
	SaveStore.save_audio_enabled(false)
	assert_false(SaveStore.load_audio_enabled(), "audio_enabled=false survives a reload")
