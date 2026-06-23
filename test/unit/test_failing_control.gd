extends "res://addons/gut/test.gd"
## E0/S0.2 quarantined failing-control.
##
## Proves the gate is NOT a no-op: with RUN_CONTROL = false this is inert
## (reported pending). Flip RUN_CONTROL to true and the suite MUST go red —
## that is the proof the gate actually catches failures.

const RUN_CONTROL := false


func test_failing_control() -> void:
	if not RUN_CONTROL:
		pending("quarantined; set RUN_CONTROL = true to verify the gate catches failures")
		return
	assert_true(false, "this MUST fail when the control is enabled")
