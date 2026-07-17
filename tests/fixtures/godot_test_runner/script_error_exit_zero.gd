extends SceneTree

const COMPLETION_MARKER := "GODOT_TEST_RUNNER_FIXTURE_COMPLETE"


func _init() -> void:
	call_deferred("_finish_with_zero")
	var invalid_target: Variant = null
	invalid_target.call("runner_fixture_missing_method")


func _finish_with_zero() -> void:
	print(COMPLETION_MARKER)
	quit(0)
