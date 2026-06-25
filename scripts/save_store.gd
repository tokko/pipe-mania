extends RefCounted
## The single persistence boundary (design: HUD/game never touch the filesystem).
## All keys live in one JSON dict in user://. Read-modify-write so independent keys (high score,
## tutorial-seen) never clobber each other. Missing or corrupt file -> defaults (never crashes).

const _PATH := "user://highscore.json"
const _MAX_LEADERBOARD := 10


static func _load() -> Dictionary:
	if not FileAccess.file_exists(_PATH):
		return {}
	var f := FileAccess.open(_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	return data if typeof(data) == TYPE_DICTIONARY else {}


static func _save(data: Dictionary) -> void:
	var f := FileAccess.open(_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


static func load_high() -> int:
	return int(_load().get("high", 0))


static func save_high(value: int) -> void:
	var d := _load()
	d["high"] = value
	_save(d)


static func load_tutorial_seen() -> bool:
	return bool(_load().get("tutorial_seen", false))


static func save_tutorial_seen(value: bool) -> void:
	var d := _load()
	d["tutorial_seen"] = value
	_save(d)


# --- Local leaderboard (top-10, online-ready: an online backend swaps in behind submit/get_top) ---

static func load_leaderboard() -> Array:
	var v = _load().get("leaderboard", [])
	return v if typeof(v) == TYPE_ARRAY else []  # wrong shape -> empty (control), never crashes


## Append an entry (name clamped to 3 upper-case chars), re-sort by score desc, trim to top-10.
static func add_leaderboard_entry(entry_name: String, score: int) -> void:
	var lb := load_leaderboard()
	lb.append({"name": entry_name.substr(0, 3).to_upper(), "score": int(score)})
	lb.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if lb.size() > _MAX_LEADERBOARD:
		lb = lb.slice(0, _MAX_LEADERBOARD)
	var d := _load()
	d["leaderboard"] = lb
	_save(d)


static func clear_leaderboard() -> void:
	var d := _load()
	d.erase("leaderboard")
	_save(d)


# --- Monetization / settings flags (read-modify-write so they never clobber each other) ---

static func load_ads_removed() -> bool:
	return bool(_load().get("ads_removed", false))


static func save_ads_removed(value: bool) -> void:
	var d := _load()
	d["ads_removed"] = value
	_save(d)


static func load_audio_enabled() -> bool:
	return bool(_load().get("audio_enabled", true))


static func save_audio_enabled(value: bool) -> void:
	var d := _load()
	d["audio_enabled"] = value
	_save(d)
