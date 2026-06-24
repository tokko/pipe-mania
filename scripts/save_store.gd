extends RefCounted
## The single high-score persistence boundary (design: HUD/game never touch the filesystem).
## Stored as JSON in user://. Missing or corrupt file -> 0 (never crashes).

const _PATH := "user://highscore.json"


static func load_high() -> int:
	if not FileAccess.file_exists(_PATH):
		return 0
	var f := FileAccess.open(_PATH, FileAccess.READ)
	if f == null:
		return 0
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY and data.has("high"):
		return int(data["high"])
	return 0


static func save_high(value: int) -> void:
	var f := FileAccess.open(_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"high": value}))
	f.close()
