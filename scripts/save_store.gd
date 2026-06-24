extends RefCounted
## The single persistence boundary (design: HUD/game never touch the filesystem).
## All keys live in one JSON dict in user://. Read-modify-write so independent keys (high score,
## tutorial-seen) never clobber each other. Missing or corrupt file -> defaults (never crashes).

const _PATH := "user://highscore.json"


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
