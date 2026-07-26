extends SceneTree
## Deterministic structured-playtest adapter. It drives the shipped main.tscn through real input
## events; it never calls gameplay methods or mutates the model directly.

const PT := preload("res://scripts/model/pipe_types.gd")

const ENGINE_NAME := "Aqueduct"
const ENGINE_VERSION := "structured-playtest-1"
const ACTIONS := ["tap_splash", "press_play", "choose_easy", "tap_first_open_cell", "tap_outside_board"]
const ENVELOPE_KEYS := ["schema_version", "scenario_id", "seed", "tick_hz", "max_ticks", "steps"]
const STEP_KEYS := ["tick", "action", "args"]

var _trace: Dictionary = {}
var _events: Array = []
var _errors: Array = []
var _main: Node
var _last_screen := ""
var _ticks := 0
var _scenario_id := "invalid-scenario"
var _seed_value := 0
var _read_error := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var raw := _read_scenario()
	if raw.is_empty():
		_finish(3 if _read_error else 2, "engine_error" if _read_error else "scenario_error")
		return
	var validation := _validate_scenario(raw)
	if not validation.is_empty():
		_errors.append(validation)
		_finish(2, "scenario_error")
		return
	_scenario_id = str(raw.scenario_id)
	_seed_value = int(raw.seed)
	seed(_seed_value)
	Engine.physics_ticks_per_second = int(raw.tick_hz)
	Engine.max_fps = int(raw.tick_hz)
	DisplayServer.window_set_size(Vector2i(720, 1280))
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	if main_scene == null:
		_errors.append(_error("ENGINE_FAILED", "production main scene could not be loaded"))
		_finish(3, "engine_error")
		return
	_main = main_scene.instantiate()
	root.add_child(_main)
	await process_frame
	if not is_instance_valid(_main) or _main.get("_screen") == null:
		_errors.append(_error("READINESS_FAILED", "production screen controller was not ready"))
		_finish(3, "engine_error")
		return
	_last_screen = _screen_name()
	_events.append(_event(0, "ready", {"scene": "main.tscn", "screen": _last_screen, "viewport_width": 720, "viewport_height": 1280}))
	var steps: Array = raw.steps
	var next_step := 0
	var last_tick := int(steps[steps.size() - 1].tick)
	for tick in range(last_tick + 1):
		_ticks = tick
		while next_step < steps.size() and int(steps[next_step].tick) == tick:
			var before := _occupied_count()
			var action_result := _perform_action(str(steps[next_step].action), steps[next_step].args)
			if not action_result.is_empty():
				_errors.append(action_result)
				_finish(3 if action_result.code == "SCENARIO_EXECUTION_FAILED" else 2, "engine_error" if action_result.code == "SCENARIO_EXECUTION_FAILED" else "scenario_error")
				return
			_events.append(_event(tick, "input_attempted", {"action": str(steps[next_step].action)}))
			await process_frame
			var after := _occupied_count()
			if after > before:
				var cell: Vector2i = _last_tapped_cell
				_events.append(_event(tick, "piece_placed", {"column": cell.x, "row": cell.y, "occupied_before": before, "occupied_after": after, "phase": _phase_name()}))
			_observe_screen()
			next_step += 1
		if next_step >= steps.size() or int(steps[next_step].tick) != tick:
			await process_frame
		_ticks = tick + 1
	_finish(0, "completed")


var _last_tapped_cell := Vector2i(-1, -1)


func _perform_action(action: String, args: Dictionary) -> Dictionary:
	if not ACTIONS.has(action):
		return _error("UNKNOWN_ACTION", "unknown action: %s" % action)
	if not args.is_empty():
		return _error("INVALID_ACTION_ARGS", "action args must be empty for %s" % action)
	var point := Vector2.ZERO
	match action:
		"tap_splash":
			point = Vector2(360, 640)
		"press_play":
			var button = _find_button(_screen_view(), "Play")
			if button == null:
				return _error("SCENARIO_EXECUTION_FAILED", "Play button input was not delivered by headless viewport")
			point = button.get_global_rect().get_center()
			_send_control_click(button, point)
			return {}
		"choose_easy":
			var easy = _find_button(_screen_view(), "Easy", "EasyButton")
			if easy == null:
				return _error("SCENARIO_EXECUTION_FAILED", "Easy button input was not delivered by headless viewport")
			point = easy.get_global_rect().get_center()
			_send_control_click(easy, point)
			return {}
		"tap_first_open_cell":
			var board_view = _main.get("_bv")
			var gs = _main.get("_gs")
			if board_view == null or gs == null:
				return _error("READINESS_FAILED", "board was not available")
			var found := false
			for y in gs.board.height:
				for x in gs.board.width:
					if gs.board.cell_at(x, y) == PT.Cell.OPEN and gs.pipe_at(x, y) == PT.Piece.NONE:
						var layout = board_view.get("layout")
						point = layout.cell_to_pixel(x, y) + Vector2(board_view.cell_size() * 0.5, board_view.cell_size() * 0.5)
						_last_tapped_cell = Vector2i(x, y)
						found = true
						break
				if found:
					break
			if not found:
				return _error("SCENARIO_EXECUTION_FAILED", "board has no open cell")
			_send_mouse(point, true)
			_send_mouse(point, false)
			return {}
		"tap_outside_board":
			var outside_view = _main.get("_bv")
			if outside_view == null:
				return _error("READINESS_FAILED", "board was not available")
			point = outside_view.get("layout").origin - Vector2(1, 1)
			_send_mouse(point, true)
			_send_mouse(point, false)
			return {}
	_last_tapped_cell = Vector2i(-1, -1)
	_send_mouse(point, true)
	_send_mouse(point, false)
	return {}


func _send_mouse(point: Vector2, pressed: bool) -> void:
	if pressed:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.get_viewport().push_input(motion)
		Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.get_viewport().push_input(event)
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_control_click(control: Control, point: Vector2) -> void:
	_send_mouse(point, true)
	_send_mouse(point, false)


func _observe_screen() -> void:
	var now := _screen_name()
	if now != _last_screen:
		_events.append(_event(_ticks, "screen_changed", {"from": _last_screen, "to": now}))
		_last_screen = now


func _screen_view():
	var screen = _main.get("_screen")
	return screen.get("_screen_view") if screen != null else null


func _screen_name() -> String:
	var screen = _main.get("_screen")
	return screen.screen_label() if screen != null else ""


func _phase_name() -> String:
	var gs = _main.get("_gs")
	return "BUILD" if gs != null and int(gs.phase) == 0 else "FLOW"


func _event(tick: int, event_type: String, data: Dictionary) -> Dictionary:
	return {"tick": tick, "type": event_type, "data": data}


func _occupied_count() -> int:
	var gs = _main.get("_gs")
	if gs == null:
		return 0
	var count := 0
	for y in gs.board.height:
		for x in gs.board.width:
			if gs.pipe_at(x, y) != PT.Piece.NONE:
				count += 1
	return count


func _find_button(node: Node, text: String, node_name: String = ""):
	if node == null:
		return null
	if node is Button and (node.text == text or (not node_name.is_empty() and node.name == node_name)):
		return node
	for child in node.get_children():
		var found = _find_button(child, text, node_name)
		if found != null:
			return found
	return null


func _read_scenario() -> Dictionary:
	var path := ""
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--scenario" and i + 1 < args.size():
			path = args[i + 1]
		elif args[i].begins_with("--scenario="):
			path = args[i].substr(11)
	if path.is_empty() or not FileAccess.file_exists(path):
		_errors.append(_error("MISSING_TRACE", "scenario file was not supplied"))
		_read_error = true
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_errors.append(_error("MALFORMED_TRACE", "scenario is not a JSON object"))
		_read_error = true
		return {}
	return parsed


func _validate_scenario(s: Dictionary) -> Dictionary:
	if s.keys().size() != ENVELOPE_KEYS.size():
		return _error("INVALID_ENVELOPE", "scenario envelope keys are not exact")
	for key in ENVELOPE_KEYS:
		if not s.has(key):
			return _error("INVALID_ENVELOPE", "scenario envelope is missing %s" % key)
	if not s.scenario_id is String or s.scenario_id.is_empty() or s.scenario_id.length() > 128:
		return _error("INVALID_ENVELOPE", "scenario_id must be a UTF-8 string of 1..128 characters")
	if not _is_integer(s.schema_version) or not _is_integer(s.seed) or not _is_integer(s.tick_hz) or not _is_integer(s.max_ticks):
		return _error("INVALID_ENVELOPE", "scenario envelope values must be integers")
	if int(s.schema_version) != 1:
		return _error("INVALID_ENVELOPE", "scenario envelope value out of range")
	if int(s.seed) < 0 or int(s.seed) > 2147483647 or int(s.tick_hz) != 60 or int(s.max_ticks) < 1 or int(s.max_ticks) > 3600:
		return _error("INVALID_ENVELOPE", "scenario envelope value out of range")
	if not s.steps is Array or s.steps.is_empty() or s.steps.size() > 256:
		return _error("INVALID_ENVELOPE", "steps must contain 1..256 entries")
	var previous := -1
	for step in s.steps:
		if not step is Dictionary or step.keys().size() != STEP_KEYS.size():
			return _error("INVALID_ENVELOPE", "step keys are not exact")
		for key in STEP_KEYS:
			if not step.has(key):
				return _error("INVALID_ENVELOPE", "step is missing %s" % key)
		if not _is_integer(step.tick) or int(step.tick) < 0 or int(step.tick) >= int(s.max_ticks) or int(step.tick) < previous:
			return _error("INVALID_ENVELOPE", "step ticks must increase within max_ticks")
		if not step.action is String:
			return _error("UNKNOWN_ACTION", "step action is not a string")
		if not step.args is Dictionary:
			return _error("INVALID_ACTION_ARGS", "step args must be an object")
		previous = int(step.tick)
	return {}


func _is_integer(value) -> bool:
	return (value is int or value is float) and is_equal_approx(float(value), floor(float(value)))


func _error(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message}


func _finish(code: int, exit_name: String) -> void:
	var available := _main != null and is_instance_valid(_main) and _main.get("_screen") != null and _main.get("_gs") != null
	_trace = {
		"schema_version": 1,
		"scenario_id": _scenario_id,
		"engine": {"name": ENGINE_NAME, "version": ENGINE_VERSION},
		"seed": _seed_value,
		"ticks_executed": _ticks,
		"exit": exit_name,
		"events": _events if code == 0 else [],
		"final_state": {"available": available, "screen": _screen_name() if available else null, "phase": _phase_name() if available else null, "occupied_count": _occupied_count() if available else null},
		"errors": _errors
	}
	if _main != null and is_instance_valid(_main):
		var args := OS.get_cmdline_args()
		for i in args.size():
			if args[i] == "--scenario" and i + 1 < args.size():
				var path := args[i + 1]
				var source = JSON.parse_string(FileAccess.get_file_as_string(path))
				if source is Dictionary:
					if source.get("scenario_id", null) is String and not str(source.scenario_id).is_empty() and str(source.scenario_id).length() <= 128:
						_trace.scenario_id = str(source.scenario_id)
					if _is_integer(source.get("seed", null)):
						_trace.seed = int(source.seed)
				break
		_main.queue_free()
	var output := JSON.stringify(_trace)
	print(output)
	quit(code)
