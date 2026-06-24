extends Node
## Drives the verify-flow animation: on a Timer, advances the model one step() per tick and
## re-renders the board (wet cells fill); when the model resolves (terminal outcome) or settles,
## stops and emits the outcome. resolve_immediately() runs the same resolution synchronously for
## the deterministic headless gate (no Timer waiting).

const GameState = preload("res://scripts/model/game_state.gd")

signal outcome_resolved(outcome: int, score: int)

const TICK := 0.12  # cosmetic water speed (not a difficulty knob — design doc)

var _gs
var _bv
var _timer: Timer


func setup(gs, board_view) -> void:
	_gs = gs
	_bv = board_view


# Begin animating the flow. Assumes the caller already called gs.go() (Main._start_flow does).
# A board that is terminal at the seed (e.g. inlet adjacent to a bomb) resolves immediately,
# matching resolve()'s pre-step check.
func start() -> void:
	if _timer == null:
		_timer = Timer.new()
		_timer.wait_time = TICK
		_timer.timeout.connect(_tick)
		add_child(_timer)
	var o = _gs.outcome_now()  # untyped _gs -> explicit var (no :=)
	if o != GameState.Outcome.NONE:
		_finish(o)
		return
	_timer.start()


func _tick() -> void:
	var advanced = _gs.step()  # untyped _gs -> explicit var (no :=)
	_bv.refresh()  # re-render wet cells (no state_changed: route readout is build-phase only)
	var o = _gs.outcome_now()
	if o != GameState.Outcome.NONE or not advanced:
		_finish(o)


func _finish(outcome: int) -> void:
	if _timer != null:
		_timer.stop()
	outcome_resolved.emit(outcome, _gs.score())


# Synchronous resolution for the headless gate. Stops the Timer first so it and resolve() never
# drive the same frontier concurrently (council RISK). Reaches the SAME outcome as the tick loop.
func resolve_immediately() -> void:
	if _timer != null:
		_timer.stop()
	var o = _gs.resolve()
	_bv.refresh()
	outcome_resolved.emit(o, _gs.score())
